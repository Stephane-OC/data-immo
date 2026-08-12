"""Importe les sept CSV nettoyés de DATAImmo dans MySQL.

À lancer depuis la racine du projet, après le script SQL de création :
    python scripts/02_import_clean_csv_mysql.py
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

import mysql.connector
import pandas as pd
from mysql.connector import Error


ROOT = Path(__file__).resolve().parents[1]
CLEAN = ROOT / "data" / "clean"

IMPORT_ORDER = [
    "region",
    "departement",
    "commune",
    "population_commune",
    "type_local",
    "bien",
    "vente",
]
TRUNCATE_ORDER = list(reversed(IMPORT_ORDER))

EXPECTED_COLUMNS = {
    "region": ["code_region", "nom_region"],
    "departement": ["code_departement", "nom_departement", "code_region"],
    "commune": [
        "id_commune",
        "code_departement",
        "code_commune",
        "nom_commune",
    ],
    "population_commune": [
        "id_commune",
        "population_municipale",
        "population_comptee_a_part",
        "population_totale",
    ],
    "type_local": ["code_type_local", "libelle_type_local"],
    "bien": [
        "id_bien",
        "id_commune",
        "numero_voie",
        "btq",
        "type_voie",
        "voie",
        "code_postal",
        "surface_carrez",
        "surface_reelle_bati",
        "nombre_pieces_principales",
        "code_type_local",
    ],
    "vente": [
        "id_vente",
        "id_bien",
        "numero_disposition",
        "date_mutation",
        "nature_mutation",
        "valeur_fonciere",
        "nombre_lots",
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import des CSV DATAImmo dans MySQL")
    parser.add_argument("--host", default="localhost", help="Hôte MySQL")
    parser.add_argument("--port", default=3306, type=int, help="Port MySQL")
    parser.add_argument("--user", default="root", help="Utilisateur MySQL")
    parser.add_argument("--password", default="", help="Mot de passe MySQL")
    parser.add_argument("--database", default="dataimmo", help="Nom de la base MySQL")
    parser.add_argument(
        "--no-reset",
        action="store_true",
        help="Ne vide pas les tables avant l'import.",
    )
    parser.add_argument(
        "--chunk-size",
        default=1000,
        type=int,
        help="Nombre de lignes insérées par lot.",
    )
    args = parser.parse_args()
    if args.chunk_size <= 0:
        parser.error("--chunk-size doit être strictement positif")
    return args


def sql_identifier(name: str) -> str:
    """Protège un identifiant MySQL avec des accents graves."""
    return "`" + name.replace("`", "``") + "`"


def clean_value(value):
    """Convertit les cellules vides des CSV en NULL MySQL."""
    if pd.isna(value):
        return None
    text = str(value).strip()
    if not text or text.lower() in {"nan", "none", "nat"}:
        return None
    return text


def chunks(rows: list[tuple], size: int) -> Iterable[list[tuple]]:
    for index in range(0, len(rows), size):
        yield rows[index : index + size]


def read_csv_for_table(table_name: str) -> pd.DataFrame:
    path = CLEAN / f"{table_name}.csv"
    if not path.exists():
        raise FileNotFoundError(f"CSV introuvable : {path}")

    frame = pd.read_csv(
        path,
        sep=";",
        dtype=str,
        encoding="utf-8-sig",
        keep_default_na=False,
    )
    frame.columns = [str(column).strip().replace("\ufeff", "") for column in frame.columns]

    expected = EXPECTED_COLUMNS[table_name]
    if list(frame.columns) != expected:
        raise ValueError(
            f"Colonnes inattendues dans {path.name}.\n"
            f"Attendu : {expected}\n"
            f"Trouvé  : {list(frame.columns)}"
        )
    return frame


def validate_csv_files() -> None:
    if not CLEAN.exists():
        raise FileNotFoundError(f"Dossier clean introuvable : {CLEAN}")
    for table in IMPORT_ORDER:
        read_csv_for_table(table)


def truncate_tables(cursor) -> None:
    print("\nVidage des tables existantes...")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
    try:
        for table in TRUNCATE_ORDER:
            cursor.execute(f"TRUNCATE TABLE {sql_identifier(table)};")
            print(f"   - {table}")
    finally:
        cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")


def import_table(cursor, table_name: str, chunk_size: int) -> int:
    frame = read_csv_for_table(table_name)
    if frame.empty:
        print(f"ATTENTION  {table_name:<22} 0 ligne à importer")
        return 0

    columns = list(frame.columns)
    placeholders = ", ".join(["%s"] * len(columns))
    column_sql = ", ".join(sql_identifier(column) for column in columns)
    query = (
        f"INSERT INTO {sql_identifier(table_name)} ({column_sql}) "
        f"VALUES ({placeholders})"
    )
    rows = [
        tuple(clean_value(value) for value in row)
        for row in frame.itertuples(index=False, name=None)
    ]

    imported = 0
    for batch in chunks(rows, chunk_size):
        cursor.executemany(query, batch)
        imported += len(batch)

    print(f"OK  {table_name:<22} {imported:>8} lignes importées")
    return imported


def count_rows(cursor, table_name: str) -> int:
    cursor.execute(f"SELECT COUNT(*) FROM {sql_identifier(table_name)};")
    return int(cursor.fetchone()[0])


def main() -> None:
    args = parse_args()
    validate_csv_files()

    print("Connexion MySQL...")
    print(f"Base      : {args.database}")
    print(f"Host/port : {args.host}:{args.port}")
    print(f"User      : {args.user}")

    try:
        connection = mysql.connector.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            password=args.password,
            database=args.database,
            charset="utf8mb4",
            use_unicode=True,
        )
    except Error as exc:
        print("\nConnexion impossible à MySQL.")
        print("Vérifie le serveur, la base, l'utilisateur et le mot de passe.")
        raise exc

    cursor = connection.cursor()
    try:
        if args.no_reset:
            print("\nMode --no-reset : les tables existantes sont conservées.")
        else:
            truncate_tables(cursor)

        print("\nImport des 7 CSV nettoyés...")
        for table in IMPORT_ORDER:
            import_table(cursor, table, args.chunk_size)
        connection.commit()

        print("\nContrôle des volumes importés...")
        for table in IMPORT_ORDER:
            print(f"   {table:<22} {count_rows(cursor, table):>8} lignes")

        print("\nImport terminé avec succès.")
    except Exception:
        connection.rollback()
        print("\nErreur pendant l'import : la transaction a été annulée.")
        raise
    finally:
        cursor.close()
        connection.close()


if __name__ == "__main__":
    main()