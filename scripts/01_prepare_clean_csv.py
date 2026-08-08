"""Prépare les sept CSV du modèle final DATAImmo.

À lancer depuis la racine du projet :
    python scripts/01_prepare_clean_csv.py

Les fichiers sources doivent se trouver dans ``data/raw``. Les données liées
au nom de l'acquéreur ne sont jamais exportées.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import pandas as pd


TABLES_IN_ORDER = [
    "region",
    "departement",
    "commune",
    "population_commune",
    "type_local",
    "bien",
    "vente",
]

# Exports de l'ancien modèle à 15 tables, retirés avant chaque régénération.
OBSOLETE_TABLES = [
    "academie",
    "aire_urbaine",
    "lot",
    "nature_culture",
    "nature_culture_speciale",
    "unite_urbaine",
    "voie",
    "zone_emploi",
]

TYPE_LOCAL_FALLBACK = {
    1: "Maison",
    2: "Appartement",
    3: "Dépendance",
    4: "Local industriel et commercial ou assimilé",
}


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Prépare les 7 CSV normalisés du projet DATAImmo."
    )
    parser.add_argument("--raw-dir", type=Path, default=root / "data" / "raw")
    parser.add_argument("--clean-dir", type=Path, default=root / "data" / "clean")
    return parser.parse_args()


def as_text(value) -> str:
    """Convertit une valeur Excel en texte propre sans altérer les codes."""
    if pd.isna(value):
        return ""

    text = str(value).strip()
    if text.lower() in {"nan", "none", "nat"}:
        return ""
    if re.fullmatch(r"\d+\.0", text):
        text = text[:-2]
    return text


def code(value, width: int | None = None) -> str:
    """Nettoie un code et conserve ses éventuels zéros initiaux."""
    text = as_text(value)
    if width and text.isdigit():
        return text.zfill(width)
    return text


def integer(value):
    text = as_text(value).replace(" ", "").replace(",", ".")
    if not text:
        return ""
    try:
        return int(float(text))
    except ValueError:
        return ""


def decimal(value):
    text = as_text(value).replace(" ", "").replace(",", ".")
    if not text:
        return ""
    try:
        return format(float(text), ".15g")
    except ValueError:
        return ""


def sql_date(value) -> str:
    """Convertit une date en ``YYYY-MM-DD`` pour Databricks et MySQL."""
    date = pd.to_datetime(value, errors="coerce", dayfirst=False)
    if pd.isna(date):
        date = pd.to_datetime(value, errors="coerce", dayfirst=True)
    return "" if pd.isna(date) else date.strftime("%Y-%m-%d")


def require_columns(frame: pd.DataFrame, columns: set[str], source_name: str) -> None:
    missing = sorted(columns.difference(frame.columns))
    if missing:
        raise ValueError(
            f"Colonnes manquantes dans {source_name} : {', '.join(missing)}"
        )


def write_csv(frame: pd.DataFrame, clean_dir: Path, table: str) -> None:
    path = clean_dir / f"{table}.csv"
    frame.to_csv(path, index=False, sep=";", encoding="utf-8-sig", na_rep="")
    print(f"OK  {table:<22} {len(frame):>8} lignes  -> {path}")


def remove_obsolete_csv(clean_dir: Path) -> None:
    """Supprime uniquement les CSV de l'ancien modèle devenus inutiles."""
    removed = []
    for table in OBSOLETE_TABLES:
        path = clean_dir / f"{table}.csv"
        if path.exists():
            path.unlink()
            removed.append(path.name)

    if removed:
        print("Anciens CSV supprimés : " + ", ".join(removed))


def validate_model(frames: dict[str, pd.DataFrame]) -> None:
    """Vérifie les clés et relations avant l'écriture des CSV."""
    primary_keys = {
        "region": "code_region",
        "departement": "code_departement",
        "commune": "id_commune",
        "population_commune": "id_commune",
        "type_local": "code_type_local",
        "bien": "id_bien",
        "vente": "id_vente",
    }

    for table, primary_key in primary_keys.items():
        frame = frames[table]
        if frame[primary_key].map(as_text).eq("").any():
            raise ValueError(f"Clé primaire vide détectée dans {table}.{primary_key}")
        if frame[primary_key].duplicated().any():
            raise ValueError(f"Clé primaire dupliquée détectée dans {table}.{primary_key}")

    relations = [
        ("departement", "code_region", "region", "code_region"),
        ("commune", "code_departement", "departement", "code_departement"),
        ("population_commune", "id_commune", "commune", "id_commune"),
        ("bien", "id_commune", "commune", "id_commune"),
        ("bien", "code_type_local", "type_local", "code_type_local"),
        ("vente", "id_bien", "bien", "id_bien"),
    ]

    for child_table, child_key, parent_table, parent_key in relations:
        child_values = set(frames[child_table][child_key].dropna())
        child_values.discard("")
        parent_values = set(frames[parent_table][parent_key].dropna())
        orphan_values = child_values.difference(parent_values)
        if orphan_values:
            raise ValueError(
                f"Relation invalide : {child_table}.{child_key} contient "
                f"{len(orphan_values)} valeur(s) absente(s) de "
                f"{parent_table}.{parent_key}."
            )


def main() -> None:
    args = parse_args()
    args.clean_dir.mkdir(parents=True, exist_ok=True)
    remove_obsolete_csv(args.clean_dir)

    dvf_path = args.raw_dir / "Valeurs-foncières.xlsx"
    population_path = args.raw_dir / "donnees_communes.xlsx"
    geo_path = args.raw_dir / "fr-esr-referentiel-geographique.xlsx"
    for path in (dvf_path, population_path, geo_path):
        if not path.exists():
            raise FileNotFoundError(f"Fichier source introuvable : {path}")

    print("Lecture des fichiers sources...")
    dvf = pd.read_excel(dvf_path, dtype=str).dropna(how="all")
    population_source = pd.read_excel(population_path, dtype=str).dropna(how="all")
    geo = pd.read_excel(geo_path, dtype=str).dropna(how="all")

    require_columns(
        geo,
        {"reg_code", "reg_nom", "dep_code", "dep_nom", "com_code", "com_nom"},
        geo_path.name,
    )
    require_columns(
        population_source,
        {"CODDEP", "CODCOM", "PMUN", "PCAP", "PTOT"},
        population_path.name,
    )
    require_columns(
        dvf,
        {
            "Code departement",
            "Code commune",
            "Code type local",
            "Type local",
            "No voie",
            "B/T/Q",
            "Type de voie",
            "Voie",
            "Code postal",
            "Surface Carrez du 1er lot",
            "Surface reelle bati",
            "Nombre pieces principales",
            "No disposition",
            "Date mutation",
            "Nature mutation",
            "Valeur fonciere",
            "Nombre de lots",
        },
        dvf_path.name,
    )

    if "Nom de l'acquereur" in dvf.columns:
        print("RGPD : la colonne Nom de l'acquereur est exclue des exports.")

    # Référentiel géographique.
    geo["code_region"] = geo["reg_code"].map(lambda value: code(value, 2))
    geo["code_departement"] = geo["dep_code"].map(lambda value: code(value, 2))
    geo["id_commune"] = geo["com_code"].map(lambda value: code(value, 5))
    geo["code_commune"] = geo["id_commune"].map(
        lambda value: value[-3:] if value else ""
    )

    region = (
        geo[["code_region", "reg_nom"]]
        .rename(columns={"reg_nom": "nom_region"})
        .query("code_region != ''")
        .drop_duplicates(subset=["code_region"])
        .sort_values("code_region")
        .reset_index(drop=True)
    )

    departement = (
        geo[["code_departement", "dep_nom", "code_region"]]
        .rename(columns={"dep_nom": "nom_departement"})
        .query("code_departement != ''")
        .drop_duplicates(subset=["code_departement"])
        .sort_values("code_departement")
        .reset_index(drop=True)
    )

    commune = (
        geo[["id_commune", "code_departement", "code_commune", "com_nom"]]
        .rename(columns={"com_nom": "nom_commune"})
        .query("id_commune != ''")
        .drop_duplicates(subset=["id_commune"])
        .sort_values("id_commune")
        .reset_index(drop=True)
    )
    valid_communes = set(commune["id_commune"])

    # Population communale.
    population_source["code_departement"] = population_source["CODDEP"].map(
        lambda value: code(value, 2)
    )
    population_source["code_commune"] = population_source["CODCOM"].map(
        lambda value: code(value, 3)
    )
    population_source["id_commune"] = (
        population_source["code_departement"]
        + population_source["code_commune"]
    )
    population_commune = pd.DataFrame(
        {
            "id_commune": population_source["id_commune"],
            "population_municipale": population_source["PMUN"].map(integer),
            "population_comptee_a_part": population_source["PCAP"].map(integer),
            "population_totale": population_source["PTOT"].map(integer),
        }
    )
    population_commune = (
        population_commune[population_commune["id_commune"].isin(valid_communes)]
        .drop_duplicates(subset=["id_commune"])
        .sort_values("id_commune")
        .reset_index(drop=True)
    )

    # Données DVF et filtre de sécurité sur les communes connues.
    dvf["id_commune"] = (
        dvf["Code departement"].map(lambda value: code(value, 2))
        + dvf["Code commune"].map(lambda value: code(value, 3))
    )
    rejected = int((~dvf["id_commune"].isin(valid_communes)).sum())
    if rejected:
        print(f"ATTENTION : {rejected} ligne(s) DVF sans commune ont été écartées.")
    dvf = dvf[dvf["id_commune"].isin(valid_communes)].copy().reset_index(drop=True)

    type_local = pd.DataFrame(
        {
            "code_type_local": dvf["Code type local"].map(integer),
            "libelle_type_local": dvf["Type local"].map(as_text),
        }
    )
    type_local = (
        type_local[type_local["code_type_local"] != ""]
        .sort_values(["code_type_local", "libelle_type_local"], ascending=[True, False])
        .drop_duplicates(subset=["code_type_local"])
        .sort_values("code_type_local")
        .reset_index(drop=True)
    )
    type_local["libelle_type_local"] = type_local.apply(
        lambda row: row["libelle_type_local"]
        or TYPE_LOCAL_FALLBACK.get(row["code_type_local"], "Non renseigné"),
        axis=1,
    )

    identifiers = pd.RangeIndex(start=1, stop=len(dvf) + 1)
    bien = pd.DataFrame(
        {
            "id_bien": identifiers,
            "id_commune": dvf["id_commune"],
            "numero_voie": dvf["No voie"].map(integer),
            "btq": dvf["B/T/Q"].map(as_text),
            "type_voie": dvf["Type de voie"].map(as_text),
            "voie": dvf["Voie"].map(as_text),
            "code_postal": dvf["Code postal"].map(lambda value: code(value, 5)),
            "surface_carrez": dvf["Surface Carrez du 1er lot"].map(decimal),
            "surface_reelle_bati": dvf["Surface reelle bati"].map(decimal),
            "nombre_pieces_principales": dvf["Nombre pieces principales"].map(integer),
            "code_type_local": dvf["Code type local"].map(integer),
        }
    )

    vente = pd.DataFrame(
        {
            "id_vente": identifiers,
            "id_bien": identifiers,
            "numero_disposition": dvf["No disposition"].map(integer),
            "date_mutation": dvf["Date mutation"].map(sql_date),
            "nature_mutation": dvf["Nature mutation"].map(as_text),
            "valeur_fonciere": dvf["Valeur fonciere"].map(decimal),
            "nombre_lots": dvf["Nombre de lots"].map(integer),
        }
    )

    frames = {
        "region": region,
        "departement": departement,
        "commune": commune,
        "population_commune": population_commune,
        "type_local": type_local,
        "bien": bien,
        "vente": vente,
    }
    validate_model(frames)

    print("\nExport des CSV nettoyés...")
    for table in TABLES_IN_ORDER:
        write_csv(frames[table], args.clean_dir, table)

    print("\nPréparation terminée : 7 CSV créés, aucune donnée d'acquéreur exportée.")


if __name__ == "__main__":
    main()