-- ============================================================
-- Projet       : DATAImmo
-- Fichier      : 04_verifications_integrite_databricks.sql
-- Objectif     : Vérifier les six relations du modèle et
--                confirmer l'exclusion des données acquéreur
-- Environnement: Databricks SQL / Unity Catalog
-- ============================================================
--
-- Prérequis :
-- 1. Avoir validé les volumes avec le fichier 02
-- 2. Avoir validé les futures PK avec le fichier 03
-- 3. Ne pas encore avoir déclaré les contraintes du fichier 05
--
-- Résultat attendu :
-- Les six contrôles de relations doivent retourner 0 ligne
-- orpheline et le contrôle RGPD ne doit retourner aucune ligne
-- ============================================================


-- ============================================================
-- 1. SÉLECTION DU CATALOGUE ET DU SCHÉMA
-- ============================================================

USE CATALOG workspace;
USE SCHEMA dataimmo;

-- ============================================================
-- 2. CONTRÔLE DES SIX RELATIONS DU MODÈLE
-- ============================================================

-- Les contrôles sont exécutés avant la déclaration des FK, car
-- Databricks ne fait pas respecter automatiquement ces contraintes
SELECT
    'departement_sans_region' AS check_name,
    COUNT(*) AS orphan_rows,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END AS statut
FROM departement d
LEFT JOIN region r
    ON d.code_region = r.code_region
WHERE r.code_region IS NULL

UNION ALL

SELECT
    'commune_sans_departement',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM commune c
LEFT JOIN departement d
    ON c.code_departement = d.code_departement
WHERE d.code_departement IS NULL

UNION ALL

SELECT
    'population_sans_commune',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM population_commune p
LEFT JOIN commune c
    ON p.id_commune = c.id_commune
WHERE c.id_commune IS NULL

UNION ALL

SELECT
    'bien_sans_commune',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM bien b
LEFT JOIN commune c
    ON b.id_commune = c.id_commune
WHERE c.id_commune IS NULL

UNION ALL

SELECT
    'bien_sans_type_local',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM bien b
LEFT JOIN type_local t
    ON b.code_type_local = t.code_type_local
-- Une valeur NULL est autorisée pour cette FK facultative et ne
-- constitue donc pas une ligne orpheline
WHERE b.code_type_local IS NOT NULL
  AND t.code_type_local IS NULL

UNION ALL

SELECT
    'vente_sans_bien',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM vente v
LEFT JOIN bien b
    ON v.id_bien = b.id_bien
WHERE b.id_bien IS NULL;

-- ============================================================
-- 3. CONTRÔLE DE L'EXCLUSION DES DONNÉES ACQUÉREUR
-- ============================================================

-- Aucun résultat n'est attendu. Les noms et prénoms fictifs du
-- fichier source ne doivent pas apparaître dans le modèle final
SELECT
    table_name,
    column_name
FROM system.information_schema.columns
WHERE table_catalog = 'workspace'
  AND table_schema = 'dataimmo'
  AND (
      LOWER(column_name) LIKE '%acqu%'
      OR LOWER(column_name) LIKE '%prenom%'
  )
ORDER BY table_name, column_name;