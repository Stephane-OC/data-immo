-- ============================================================
-- Projet       : DATAImmo
-- Fichier      : 02_verifications_nombres_databricks.sql
-- Objectif     : Comparer le nombre de lignes importées dans
--                Databricks avec le nombre de lignes des CSV
-- Environnement: Databricks SQL / Unity Catalog
-- ============================================================
--
-- Prérequis :
-- 1. Avoir exécuté 01_creation_schema_databricks.sql.
-- 2. Avoir importé les sept CSV dans "workspace.dataimmo"
--
-- Résultat attendu :
-- Les colonnes expected_csv_rows et databricks_rows doivent être
-- identiques pour les sept tables. Chaque statut doit être "OK"
-- ============================================================


-- ============================================================
-- 1. SÉLECTION DU CATALOGUE ET DU SCHÉMA
-- ============================================================

USE CATALOG workspace;
USE SCHEMA dataimmo;

-- ============================================================
-- 2. COMPARAISON DES VOLUMES CSV / DATABRICKS
-- ============================================================

-- Un statut "A CONTROLER" indique qu'une table doit être réimportée
-- ou que son fichier CSV doit être vérifié
SELECT
    'region' AS table_name,
    19 AS expected_csv_rows,
    COUNT(*) AS databricks_rows,
    CASE WHEN COUNT(*) = 19 THEN 'OK' ELSE 'A CONTROLER' END AS statut
FROM region

UNION ALL

SELECT
    'departement',
    109,
    COUNT(*),
    CASE WHEN COUNT(*) = 109 THEN 'OK' ELSE 'A CONTROLER' END
FROM departement

UNION ALL

SELECT
    'commune',
    38916,
    COUNT(*),
    CASE WHEN COUNT(*) = 38916 THEN 'OK' ELSE 'A CONTROLER' END
FROM commune

UNION ALL

SELECT
    'population_commune',
    34991,
    COUNT(*),
    CASE WHEN COUNT(*) = 34991 THEN 'OK' ELSE 'A CONTROLER' END
FROM population_commune

UNION ALL

SELECT
    'type_local',
    2,
    COUNT(*),
    CASE WHEN COUNT(*) = 2 THEN 'OK' ELSE 'A CONTROLER' END
FROM type_local

UNION ALL

SELECT
    'bien',
    34169,
    COUNT(*),
    CASE WHEN COUNT(*) = 34169 THEN 'OK' ELSE 'A CONTROLER' END
FROM bien

UNION ALL

SELECT
    'vente',
    34169,
    COUNT(*),
    CASE WHEN COUNT(*) = 34169 THEN 'OK' ELSE 'A CONTROLER' END
FROM vente;