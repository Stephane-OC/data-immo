from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd


TABLES = [
    "region",
    "departement",
    "commune",
    "population_commune",
    "type_local",
    "bien",
    "vente",
]

EXPECTED_COLUMNS = {
    "region": ["code_region", "nom_region"],
    "departement": ["code_departement", "nom_departement", "code_region"],
    "commune": ["id_commune", "code_departement", "code_commune", "nom_commune"],
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

PRIMARY_KEYS = {
    "region": "code_region",
    "departement": "code_departement",
    "commune": "id_commune",
    "population_commune": "id_commune",
    "type_local": "code_type_local",
    "bien": "id_bien",
    "vente": "id_vente",
}

FOREIGN_KEYS = [
    ("departement", "code_region", "region", "code_region"),
    ("commune", "code_departement", "departement", "code_departement"),
    ("population_commune", "id_commune", "commune", "id_commune"),
    ("bien", "id_commune", "commune", "id_commune"),
    ("bien", "code_type_local", "type_local", "code_type_local"),
    ("vente", "id_bien", "bien", "id_bien"),
]

EXPECTED_ROWS = {
    "region": 19,
    "departement": 109,
    "commune": 38916,
    "population_commune": 34991,
    "type_local": 2,
    "bien": 34169,
    "vente": 34169,
}


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description="Vérifie les 7 CSV DATAImmo.")
    parser.add_argument("--clean-dir", type=Path, default=root / "data" / "clean")
    parser.add_argument("--reports-dir", type=Path, default=root / "reports")
    return parser.parse_args()


def read_csv(path: Path) -> pd.DataFrame:
    frame = pd.read_csv(
        path,
        sep=";",
        dtype=str,
        encoding="utf-8-sig",
        keep_default_na=False,
    )
    frame.columns = [column.strip().replace("\ufeff", "") for column in frame.columns]
    return frame


def write_reports(
    reports_dir: Path,
    frames: dict[str, pd.DataFrame],
    errors: list[str],
) -> tuple[Path, Path]:
    """Réécrit les deux rapports avec le modèle final à 7 tables."""
    reports_dir.mkdir(parents=True, exist_ok=True)

    counts_path = reports_dir / "clean_csv_row_counts.csv"
    report_path = reports_dir / "clean_csv_verification_report.txt"

    counts = pd.DataFrame(
        [
            {
                "table_name": table,
                "csv_rows": len(frames[table]) if table in frames else 0,
                "expected_rows": EXPECTED_ROWS[table],
                "status": (
                    "OK"
                    if table in frames and len(frames[table]) == EXPECTED_ROWS[table]
                    else "FAIL"
                ),
            }
            for table in TABLES
        ]
    )
    counts.to_csv(
        counts_path,
        index=False,
        sep=";",
        encoding="utf-8-sig",
    )

    lines = [
        "Projet DATAImmo - Rapport de vérification des CSV nettoyés",
        "=" * 72,
        f"Généré le : {datetime.now().strftime('%d/%m/%Y à %H:%M:%S')}",
        f"Statut    : {'ÉCHEC' if errors else 'VALIDÉ'}",
        "",
        "Volumes des 7 CSV clean :",
        "-" * 72,
    ]
    for table in TABLES:
        actual = len(frames[table]) if table in frames else 0
        expected = EXPECTED_ROWS[table]
        status = "OK" if actual == expected else "FAIL"
        lines.append(
            f"[{status}] {table:<24} {actual:>8} lignes "
            f"(attendu : {expected})"
        )

    lines.extend(
        [
            "",
            "Contrôles du modèle final :",
            "-" * 72,
        ]
    )

    if errors:
        lines.append(f"[FAIL] {len(errors)} erreur(s) détectée(s)")
        lines.extend(f"[FAIL] {error}" for error in errors)
    else:
        lines.extend(
            [
                "[OK] Les colonnes des 7 tables correspondent au modèle final.",
                "[OK] Les 7 clés primaires sont uniques et non vides.",
                "[OK] Les 6 relations ne contiennent aucune valeur orpheline.",
                "[OK] La période des ventes va du 02/01/2020 au 30/06/2020.",
                "[OK] Les types de biens attendus sont Maison et Appartement.",
                "[OK] Aucune colonne liée au nom de l'acquéreur n'est exportée.",
            ]
        )

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return counts_path, report_path


def main() -> None:
    args = parse_args()
    errors: list[str] = []
    frames: dict[str, pd.DataFrame] = {}

    for table in TABLES:
        path = args.clean_dir / f"{table}.csv"
        if not path.exists():
            errors.append(f"Fichier manquant : {path}")
            continue
        frame = read_csv(path)
        frames[table] = frame
        if list(frame.columns) != EXPECTED_COLUMNS[table]:
            errors.append(
                f"{table}: colonnes incorrectes. Reçu {list(frame.columns)}"
            )
        if len(frame) != EXPECTED_ROWS[table]:
            errors.append(
                f"{table}: {len(frame)} lignes au lieu de {EXPECTED_ROWS[table]}"
            )

    for table, key in PRIMARY_KEYS.items():
        if table not in frames:
            continue
        values = frames[table][key].str.strip()
        nulls = int(values.eq("").sum())
        duplicates = int(values.duplicated(keep=False).sum())
        if nulls or duplicates:
            errors.append(
                f"{table}.{key}: {nulls} valeur(s) vide(s), "
                f"{duplicates} ligne(s) dupliquée(s)"
            )

    for child, child_key, parent, parent_key in FOREIGN_KEYS:
        if child not in frames or parent not in frames:
            continue
        values = frames[child][child_key].str.strip()
        parents = set(frames[parent][parent_key].str.strip())
        orphans = int((~values.isin(parents)).sum())
        if orphans:
            errors.append(
                f"{child}.{child_key} -> {parent}.{parent_key}: "
                f"{orphans} valeur(s) orpheline(s)"
            )

    sensitive = []
    for table, frame in frames.items():
        for column in frame.columns:
            if "acqu" in column.lower():
                sensitive.append(f"{table}.{column}")
    if sensitive:
        errors.append(f"Colonnes sensibles détectées : {sensitive}")

    if "vente" in frames:
        dates = pd.to_datetime(frames["vente"]["date_mutation"], errors="coerce")
        if dates.isna().any():
            errors.append("vente.date_mutation contient des dates invalides")
        elif dates.min().date().isoformat() != "2020-01-02" or dates.max().date().isoformat() != "2020-06-30":
            errors.append(
                "Période inattendue : "
                f"{dates.min().strftime('%d/%m/%Y')} au "
                f"{dates.max().strftime('%d/%m/%Y')}"
            )

    if "bien" in frames:
        codes = set(frames["bien"]["code_type_local"])
        if codes != {"1", "2"}:
            errors.append(f"Types de biens inattendus : {sorted(codes)}")

    counts_path, report_path = write_reports(args.reports_dir, frames, errors)

    if errors:
        print("ECHEC DES CONTRÔLES")
        for error in errors:
            print(f"- {error}")
        print(f"- rapport des volumes : {counts_path}")
        print(f"- rapport détaillé    : {report_path}")
        sys.exit(1)

    print("TOUS LES CONTRÔLES SONT VALIDÉS")
    for table in TABLES:
        print(f"- {table:<22} {len(frames[table]):>8} lignes")
    print("- 7 clés primaires uniques et non vides")
    print("- 6 relations sans valeur orpheline")
    print("- aucune colonne liée à l'acquéreur")
    print(f"- rapport des volumes : {counts_path}")
    print(f"- rapport détaillé    : {report_path}")


if __name__ == "__main__":
    main()