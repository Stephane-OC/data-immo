-- ============================================================
-- Projet       : DATAImmo
-- Fichier      : 03_verifications_doublons_databricks.sql
-- Objectif     : Vérifier l'absence de valeurs NULL et de
--                doublons dans les sept futures clés primaires
-- Environnement: Databricks SQL / Unity Catalog
-- ============================================================
--
-- Prérequis :
-- 1. Avoir validé les volumes avec le fichier 02
-- 2. Ne pas encore avoir déclaré les contraintes du fichier 05
--
-- Résultat attendu :
-- Chaque valeur null_keys et duplicate_keys doit être égale à 0
-- Tous les statuts doivent être "OK" avant de déclarer les PK
-- ============================================================


-- ============================================================
-- 1. SÉLECTION DU CATALOGUE ET DU SCHÉMA
-- ============================================================

USE CATALOG workspace;
USE SCHEMA dataimmo;

-- ============================================================
-- 2. CONTRÔLE DES VALEURS NULL DANS LES FUTURES PK
-- ============================================================

SELECT
    'region' AS table_name,
    SUM(CASE WHEN code_region IS NULL THEN 1 ELSE 0 END) AS null_keys,
    CASE
        WHEN SUM(CASE WHEN code_region IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END AS statut
FROM region

UNION ALL

SELECT
    'departement',
    SUM(CASE WHEN code_departement IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN code_departement IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END
FROM departement

UNION ALL

SELECT
    'commune',
    SUM(CASE WHEN id_commune IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN id_commune IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END
FROM commune

UNION ALL

SELECT
    'population_commune',
    SUM(CASE WHEN id_commune IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN id_commune IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END
FROM population_commune

UNION ALL

SELECT
    'type_local',
    SUM(CASE WHEN code_type_local IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN code_type_local IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END
FROM type_local

UNION ALL

SELECT
    'bien',
    SUM(CASE WHEN id_bien IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN id_bien IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END
FROM bien

UNION ALL

SELECT
    'vente',
    SUM(CASE WHEN id_vente IS NULL THEN 1 ELSE 0 END),
    CASE
        WHEN SUM(CASE WHEN id_vente IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'OK' ELSE 'A CONTROLER'
    END
FROM vente;

-- ============================================================
-- 3. CONTRÔLE DES DOUBLONS DANS LES FUTURES PK
-- ============================================================

-- duplicate_keys compte le nombre de valeurs de clé apparaissant
-- plusieurs fois, et non le nombre total de lignes concernées
SELECT
    'region' AS table_name,
    COUNT(*) AS duplicate_keys,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END AS statut
FROM (
    SELECT code_region
    FROM region
    GROUP BY code_region
    HAVING COUNT(*) > 1
) duplicate_region

UNION ALL

SELECT
    'departement',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM (
    SELECT code_departement
    FROM departement
    GROUP BY code_departement
    HAVING COUNT(*) > 1
) duplicate_departement

UNION ALL

SELECT
    'commune',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM (
    SELECT id_commune
    FROM commune
    GROUP BY id_commune
    HAVING COUNT(*) > 1
) duplicate_commune

UNION ALL

SELECT
    'population_commune',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM (
    SELECT id_commune
    FROM population_commune
    GROUP BY id_commune
    HAVING COUNT(*) > 1
) duplicate_population

UNION ALL

SELECT
    'type_local',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM (
    SELECT code_type_local
    FROM type_local
    GROUP BY code_type_local
    HAVING COUNT(*) > 1
) duplicate_type_local

UNION ALL

SELECT
    'bien',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM (
    SELECT id_bien
    FROM bien
    GROUP BY id_bien
    HAVING COUNT(*) > 1
) duplicate_bien

UNION ALL

SELECT
    'vente',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'A CONTROLER' END
FROM (
    SELECT id_vente
    FROM vente
    GROUP BY id_vente
    HAVING COUNT(*) > 1
) duplicate_vente;