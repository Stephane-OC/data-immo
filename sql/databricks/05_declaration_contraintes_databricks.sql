-- ============================================================
-- Projet       : DATAImmo
-- Fichier      : 05_declaration_contraintes_databricks.sql
-- Objectif     : Déclarer les sept clés primaires et les six
--                clés étrangères du modèle relationnel final
-- Environnement: Databricks SQL / Unity Catalog
-- ============================================================
--
-- Prérequis :
-- 1. Utiliser le catalogue Unity Catalog "workspace"
-- 2. Avoir importé les sept tables au format Delta
-- 3. Avoir obtenu uniquement des statuts "OK" dans les fichiers
--    02, 03 et 04 avant de déclarer les contraintes
--
-- IMPORTANT :
-- Les clés primaires et étrangères de Databricks sont des
-- contraintes informatives "NOT ENFORCED". Elles documentent le
-- modèle, mais Databricks ne bloque pas automatiquement les
-- doublons ni les lignes orphelines. Les contrôles SQL restent
-- donc indispensables
--
-- Ce script est prévu pour des tables fraîchement recréées avec
-- le fichier 01. Une seconde exécution sans recréer le schéma
-- provoquerait une erreur, car les contraintes existent déjà
--
-- Résultat attendu :
-- 7 contraintes PRIMARY KEY et 6 contraintes FOREIGN KEY, soit
-- 13 contraintes informatives au total
-- ============================================================


-- ============================================================
-- 1. SÉLECTION DU CATALOGUE ET DU SCHÉMA
-- ============================================================

USE CATALOG workspace;
USE SCHEMA dataimmo;

-- ============================================================
-- 2. PASSAGE DES SEPT COLONNES DE PK EN NOT NULL
-- ============================================================

-- Databricks exige qu'une colonne soit NOT NULL avant de pouvoir
-- l'utiliser dans une contrainte PRIMARY KEY ajoutée à une table
ALTER TABLE region
    ALTER COLUMN code_region SET NOT NULL;

ALTER TABLE departement
    ALTER COLUMN code_departement SET NOT NULL;

ALTER TABLE commune
    ALTER COLUMN id_commune SET NOT NULL;

ALTER TABLE population_commune
    ALTER COLUMN id_commune SET NOT NULL;

ALTER TABLE type_local
    ALTER COLUMN code_type_local SET NOT NULL;

ALTER TABLE bien
    ALTER COLUMN id_bien SET NOT NULL;

ALTER TABLE vente
    ALTER COLUMN id_vente SET NOT NULL;

-- ============================================================
-- 3. DÉCLARATION DES SEPT CLÉS PRIMAIRES
-- ============================================================

ALTER TABLE region
    ADD CONSTRAINT pk_region
    PRIMARY KEY (code_region) NOT ENFORCED;

ALTER TABLE departement
    ADD CONSTRAINT pk_departement
    PRIMARY KEY (code_departement) NOT ENFORCED;

ALTER TABLE commune
    ADD CONSTRAINT pk_commune
    PRIMARY KEY (id_commune) NOT ENFORCED;

ALTER TABLE population_commune
    ADD CONSTRAINT pk_population_commune
    PRIMARY KEY (id_commune) NOT ENFORCED;

ALTER TABLE type_local
    ADD CONSTRAINT pk_type_local
    PRIMARY KEY (code_type_local) NOT ENFORCED;

ALTER TABLE bien
    ADD CONSTRAINT pk_bien
    PRIMARY KEY (id_bien) NOT ENFORCED;

ALTER TABLE vente
    ADD CONSTRAINT pk_vente
    PRIMARY KEY (id_vente) NOT ENFORCED;

-- ============================================================
-- 4. DÉCLARATION DES SIX CLÉS ÉTRANGÈRES
-- ============================================================

-- departement.code_region -> region.code_region
ALTER TABLE departement
    ADD CONSTRAINT fk_departement_region
    FOREIGN KEY (code_region)
    REFERENCES region (code_region) NOT ENFORCED;

-- commune.code_departement -> departement.code_departement
ALTER TABLE commune
    ADD CONSTRAINT fk_commune_departement
    FOREIGN KEY (code_departement)
    REFERENCES departement (code_departement) NOT ENFORCED;

-- population_commune.id_commune -> commune.id_commune
ALTER TABLE population_commune
    ADD CONSTRAINT fk_population_commune
    FOREIGN KEY (id_commune)
    REFERENCES commune (id_commune) NOT ENFORCED;

-- bien.id_commune -> commune.id_commune
ALTER TABLE bien
    ADD CONSTRAINT fk_bien_commune
    FOREIGN KEY (id_commune)
    REFERENCES commune (id_commune) NOT ENFORCED;

-- bien.code_type_local -> type_local.code_type_local
ALTER TABLE bien
    ADD CONSTRAINT fk_bien_type_local
    FOREIGN KEY (code_type_local)
    REFERENCES type_local (code_type_local) NOT ENFORCED;

-- vente.id_bien -> bien.id_bien
ALTER TABLE vente
    ADD CONSTRAINT fk_vente_bien
    FOREIGN KEY (id_bien)
    REFERENCES bien (id_bien) NOT ENFORCED;

-- ============================================================
-- 5. VÉRIFICATION DES CONTRAINTES DÉCLARÉES
-- ============================================================

-- La première requête doit retourner 13 lignes : 7 PRIMARY KEY
-- et 6 FOREIGN KEY
SELECT
    table_name,
    constraint_name,
    constraint_type
FROM system.information_schema.table_constraints
WHERE constraint_catalog = 'workspace'
  AND constraint_schema = 'dataimmo'
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY constraint_type, table_name, constraint_name;

-- Cette synthèse doit retourner pk_count = 7, fk_count = 6 et
-- le statut "OK"
SELECT
    SUM(CASE WHEN constraint_type = 'PRIMARY KEY' THEN 1 ELSE 0 END) AS pk_count,
    SUM(CASE WHEN constraint_type = 'FOREIGN KEY' THEN 1 ELSE 0 END) AS fk_count,
    CASE
        WHEN SUM(CASE WHEN constraint_type = 'PRIMARY KEY' THEN 1 ELSE 0 END) = 7
         AND SUM(CASE WHEN constraint_type = 'FOREIGN KEY' THEN 1 ELSE 0 END) = 6
        THEN 'OK'
        ELSE 'A CONTROLER'
    END AS statut
FROM system.information_schema.table_constraints
WHERE constraint_catalog = 'workspace'
  AND constraint_schema = 'dataimmo'
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY');
