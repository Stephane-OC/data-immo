-- ============================================================
-- Projet DATAImmo
-- Fichier : 01_creation_bdd_DATAImmo.sql
-- Objectif : création du modèle relationnel final à 7 tables
--             normalisé en troisième forme normale (3NF)
-- SGBD : MySQL 8 / MySQL Workbench
-- ============================================================
--
-- ATTENTION : ce script supprime puis recrée entièrement la base
-- dataimmo. Toutes les données déjà présentes seront effacées.
--
-- À exécuter AVANT :
--   1. la génération des CSV avec
--      scripts/01_prepare_clean_csv.py
--   2. leur import avec
--      scripts/02_import_clean_csv_mysql.py
--   3. les contrôles 02_verify_clean_csv.py
--
-- Ce fichier :
--   1. recrée la base dataimmo avec l'encodage utf8mb4
--   2. crée les 7 tables du modèle final
--   3. déclare les 7 clés primaires et les 6 clés étrangères
--   4. ajoute les index utiles aux jointures et aux analyses
-- ============================================================

-- ============================================================
-- 1. Création de la base de données DATAIMMO
--
-- DROP DATABASE garantit un environnement propre avant import
-- utf8mb4 permet de conserver correctement les accents et les
-- caractères spéciaux présents dans les libellés géographiques
-- ============================================================

DROP DATABASE IF EXISTS dataimmo;
CREATE DATABASE dataimmo
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE dataimmo;

-- ============================================================
-- 2. Référentiel géographique
--
-- Les quatre tables suivantes structurent les régions, les
-- départements, les communes et leurs données de population
-- L'ordre de création respecte les dépendances entre les tables
-- ============================================================

-- ============================================================
-- 2.1. Table REGION
-- Référentiel des 19 régions présentes dans les données sources
-- ============================================================

CREATE TABLE region (
  code_region VARCHAR(2) NOT NULL,
  nom_region VARCHAR(100) NOT NULL,
  CONSTRAINT pk_region PRIMARY KEY (code_region)
) ENGINE=InnoDB;

-- ============================================================
-- 2.2. Table DEPARTEMENT
-- Référentiel des départements reliés à leur région
-- ============================================================

CREATE TABLE departement (
  code_departement VARCHAR(3) NOT NULL,
  nom_departement VARCHAR(100) NOT NULL,
  code_region VARCHAR(2) NOT NULL,
  CONSTRAINT pk_departement PRIMARY KEY (code_departement),
  CONSTRAINT fk_departement_region
    FOREIGN KEY (code_region)
    REFERENCES region (code_region)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 2.3. Table COMMUNE
-- Référentiel des communes reliées à leur département
--
-- id_commune correspond à la concaténation normalisée du code
-- département et du code commune
-- ============================================================

CREATE TABLE commune (
  id_commune VARCHAR(6) NOT NULL,
  code_departement VARCHAR(3) NOT NULL,
  code_commune VARCHAR(3) NOT NULL,
  nom_commune VARCHAR(150) NOT NULL,
  CONSTRAINT pk_commune PRIMARY KEY (id_commune),
  CONSTRAINT fk_commune_departement
    FOREIGN KEY (code_departement)
    REFERENCES departement (code_departement)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 2.4. Table POPULATION_COMMUNE
-- Données démographiques reliées aux communes disponibles
-- ============================================================

CREATE TABLE population_commune (
  id_commune VARCHAR(6) NOT NULL,
  population_municipale BIGINT UNSIGNED NULL,
  population_comptee_a_part BIGINT UNSIGNED NULL,
  population_totale BIGINT UNSIGNED NULL,
  CONSTRAINT pk_population_commune PRIMARY KEY (id_commune),
  CONSTRAINT fk_population_commune_commune
    FOREIGN KEY (id_commune)
    REFERENCES commune (id_commune)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 3. Référentiel immobilier et biens
--
-- Les trois tables suivantes décrivent les types de locaux, les
-- biens immobiliers et les ventes associées
-- ============================================================

-- ============================================================
-- 3.1. Table TYPE_LOCAL
-- Référentiel des types de locaux retenus pour les analyses
-- ============================================================

CREATE TABLE type_local (
  code_type_local SMALLINT UNSIGNED NOT NULL,
  libelle_type_local VARCHAR(100) NOT NULL,
  CONSTRAINT pk_type_local PRIMARY KEY (code_type_local)
) ENGINE=InnoDB;

-- ============================================================
-- 3.2. Table BIEN
-- Caractéristiques physiques et localisation des biens
-- ============================================================

CREATE TABLE bien (
  id_bien BIGINT UNSIGNED NOT NULL,
  id_commune VARCHAR(6) NOT NULL,
  numero_voie BIGINT UNSIGNED NULL,
  btq VARCHAR(10) NULL,
  type_voie VARCHAR(30) NULL,
  voie VARCHAR(150) NULL,
  code_postal VARCHAR(5) NULL,
  surface_carrez DECIMAL(10,2) NULL,
  surface_reelle_bati DECIMAL(10,2) NULL,
  nombre_pieces_principales SMALLINT UNSIGNED NULL,
  code_type_local SMALLINT UNSIGNED NULL,
  CONSTRAINT pk_bien PRIMARY KEY (id_bien),
  CONSTRAINT fk_bien_commune
    FOREIGN KEY (id_commune)
    REFERENCES commune (id_commune)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_bien_type_local
    FOREIGN KEY (code_type_local)
    REFERENCES type_local (code_type_local)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 3.3. Table VENTE
-- Transactions immobilières reliées aux biens concernés
-- ============================================================

CREATE TABLE vente (
  id_vente BIGINT UNSIGNED NOT NULL,
  id_bien BIGINT UNSIGNED NOT NULL,
  numero_disposition INT UNSIGNED NULL,
  date_mutation DATE NOT NULL,
  nature_mutation VARCHAR(80) NOT NULL,
  valeur_fonciere DECIMAL(14,2) NULL,
  nombre_lots INT UNSIGNED NULL,
  CONSTRAINT pk_vente PRIMARY KEY (id_vente),
  CONSTRAINT fk_vente_bien
    FOREIGN KEY (id_bien)
    REFERENCES bien (id_bien)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 4. Index utiles aux jointures et aux analyses métier
--
-- Ces index accélèrent les jointures géographiques, les relations
-- entre biens et ventes ainsi que les filtres sur les transactions
-- ============================================================

CREATE INDEX idx_departement_region
  ON departement (code_region);

CREATE INDEX idx_commune_departement
  ON commune (code_departement);

CREATE INDEX idx_bien_commune
  ON bien (id_commune);

CREATE INDEX idx_bien_type_local
  ON bien (code_type_local);

CREATE INDEX idx_vente_bien
  ON vente (id_bien);

CREATE INDEX idx_vente_date
  ON vente (date_mutation);

CREATE INDEX idx_vente_valeur
  ON vente (valeur_fonciere);

-- ============================================================
-- Modèle créé :
--   7 tables
--   33 colonnes
--   7 clés primaires
--   6 clés étrangères
--
-- Étapes suivantes :
--   1. Exécuter scripts/01_prepare_clean_csv.py
--   2. Exécuter scripts/02_import_clean_csv_mysql.py
--   3. Exécuter 02_verifications_mysql.sql
-- ============================================================