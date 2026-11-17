# Catalog builder

Builds the medical catalog that doctor and admin devices download (spec 6.9, 9.5 and Appendix A). It reads the Egyptian drug dataset, LOINC and the mapping files in `mappings/`, and writes one SQLite file with full-text search, compressed for download.

> **Medical review needed before publishing (spec A.1 step 4).** The medicine groups, the class mapping, the specialty profiles, the aliases and all Arabic names were prepared by a developer. A doctor or pharmacist must review them before version 1 is published. See [What needs a doctor's review](#what-needs-a-doctors-review).

## Run it

You need Dart 3.12 (comes with Flutter 3.44). From this folder:

```sh
dart pub get
dart run bin/build_catalog.dart --sources <folder> [--drugs <csv>] [--drug-source-date YYYY-MM-DD]
```

- `--sources`: the folder that holds `loinc/<release>/`, the unpacked LOINC release (`LoincTable/`, `AccessoryFiles/`, ...). The highest release folder is used unless you pass `--loinc-release 2.83`.
- `--drugs`: the drug CSV. If you leave it out, the builder uses the newest `<sources>/drugs/<folder>/egyptian-drugs.csv`, and `--drug-source-date` defaults to that folder's name.
- `--out` (default `out`) and `--mappings` (default `mappings`).
- `--catalog-version`: defaults to the highest version already in `--out`, plus 1.
- `--allow-drop`: accept a count more than 5% below the previous version (A.8).
- `--keep-withdrawn`: keep products marked `(CANCELLED)`, `(ILLEGAL IMPORT)` or `(WITHDRAWAL)` (left out by default).

The last real build was:

```sh
dart run bin/build_catalog.dart --sources D:\freelancer\Doctory\tools\catalog-builder\sources --drugs sources\drugs\2026-06\egyptian-drugs.csv --drug-source-date 2026-06-20
```

It writes to `out/`:

| File | What |
|---|---|
| `catalog-v<n>.sqlite.gz` | The file to upload in AD20. |
| `catalog-v<n>.json` | Manifest: `catalog_version`, `schema_version`, `file`, `sha256` (of the .gz), `size_bytes`, `uncompressed_size_bytes`, `counts` (drugs, labs, radiology, ingredients), `drug_source_date`, `loinc_release`, `built_at`. |
| `catalog-v<n>.sqlite` | The same file uncompressed, to inspect. |
| `catalog-v<n>-report.txt` | Everything the build printed: counts, unmapped classes, Arabic coverage, checks, sizes. |
| `catalog-v<n>-drug-classes.csv` | Every raw class with its group, how it was chosen and its product count, for review. |

The build **fails** (exit code 1, no `.gz` or manifest) if any check fails: see [Checks](#checks-a8-and-ac-18).

Tests: `dart test` here and in `packages/catalog_core`. Two tests use the real drug CSV and are skipped when it is not in `sources/drugs/`.

`sources/` and `out/` are in `.gitignore`. **Never commit LOINC files** (spec A.7).

## Sources used last time

| Source | Version | Notes |
|---|---|---|
| Egyptian drug dataset, [karem505/egyptian-drug-database](https://github.com/karem505/egyptian-drug-database) `data/egyptian-drugs.csv`, CC0 | Repository commit `7d76aa2ac3474684f142aefa52452e1963eb0cc6` (2026-10-24). The CSV last changed in commit `82809ebb972adf976d5301689cdab68b00346f71` (2026-06-20, "Refresh prices from Drug Eye — June 2026"). Downloaded 2026-11-17. sha256 `43f91aaf53537222dcdcf538c41e125c4e5d65570a77c4e044e38f1ce107f030`. | **25,070 rows**, counted. That commit says the dataset was built from the Drug Eye registry (drugeye.pharorg.com). |
| LOINC | 2.83, unpacked at `D:\freelancer\Doctory\tools\catalog-builder\sources\loinc\2.83` | 112,405 terms. Arabic (Jordan) linguistic variant `arJO32LinguisticVariant.csv`: 1,273 terms. Universal Lab Orders Value Set: 1,519 codes. RSNA Radiology Playbook: 7,016 procedures. |

## Last build (catalog v1, schema v1)

| | |
|---|---|
| Medicines | **24,715** (25,070 rows read; 355 left out: 255 cancelled, 99 illegal import, 1 withdrawn). 1,208 are marked N/A and 86 N/A YET (kept, `status` 1 and 2). 8,344 distinct active ingredients. |
| Group "other" | **658 products (2.7%)**, mostly the junk classes `.` (257) and empty (89). 44 junk-class products were placed by the ingredient fallback. Every distinct raw class is in `class-to-group.csv`. |
| Strength found / form suggested | 12,873 (52.1%) / 24,356 (98.5%) |
| Lab tests | **43,459**: 81 marked Egypt priority by our aliases, 1,414 common (Universal Lab Orders or COMMON_ORDER_RANK). 6 left out for third-party copyright. Largest classes: MICRO 13,877, DRUG/TOX 8,567, CHEM 7,158, ALLERGY 3,564, SERO 2,824. |
| Radiology procedures | **6,941** (active Playbook procedures) |
| Arabic names | Labs 1,244 of 43,459 (1,188 from the LOINC Arabic variant, the rest from our aliases). Radiology 48 of 6,941 (ours only; LOINC has none). Every radiology procedure can also be found by Arabic modality and region words (`radiology-terms.csv`). |
| Size | **20,332,544 bytes (19.4 MB) uncompressed, 7,242,557 bytes (6.9 MB) gzip -9** (35.6%). Largest parts: lab full-text index 6.2 MB, lab table 4.8 MB, drug table 3.8 MB. |
| sha256 of the .gz | `d875cfbf6ebc0ce895a1933917decef045012ff93154f77b88cb1f3474cbca27` (changes with every build, because `built_at` is inside the file) |
| Build time | about 10 s |

Search speed on the built file (Windows desktop, 50 results, ranked): queries of two letters or more take 0.2 to 15 ms. One-letter queries take 12 to 60 ms because thousands of rows must be ranked, so **the app should start searching from the second letter**. Phones will be several times slower; measure there too (A.8).

## Checks (A.8 and AC-18)

The builder runs these on the file it just wrote and fails if any does not pass:

- Share of medicines in group `other` at most 5%.
- No count (drugs, labs, radiology, ingredients) more than 5% below the previous manifest in `out/` (unless `--allow-drop`).
- FTS5 `integrity-check` on the three full-text tables, SQLite `quick_check`, every drug has a known group.
- AC-18, with the same normalization and SQL the app will use (`catalog_core`):
  - a cardiologist types "ator": atorvastatin brands are in the specialty section (Cardiology + General groups), and none are outside it;
  - "omep" finds omeprazole for a cardiologist, through the General profile;
  - a heart medicine ("bisoprolol") is under other specialties for a dermatologist;
  - «بنادول» finds Panadol;
  - "paracetamol" returns every product whose active ingredient contains paracetamol (284 of 284);
  - "CBC" and «صورة دم كاملة» find the complete blood count (the code `aliases.csv` names "CBC") in the top 5.
- Every alias marked `priority` in `aliases.csv`, typed in English and in Arabic, finds its own code in the top 5 (316 searches).

Before running, the builder also stops if a mapping row points at something that does not exist: an alias for a LOINC code that is not an active orderable lab or Playbook procedure, a specialty profile code, region, modality or route that is not in the catalog, an unknown group or specialty.

Last result: **all checks pass.** AC-18 details are in `out/catalog-v1-report.txt`.

## The file

The schema is in `packages/catalog_core/lib/src/schema.dart` (version 1). The app opens the file read-only and refuses a `meta.schema_version` it does not know. Tables, as in spec 9.5, plus the additions marked **+**:

| Table | Columns |
|---|---|
| `meta` | `schema_version, catalog_version, built_at, drug_source_date, loinc_release` (one row) |
| `drug_groups` | `id, name_en, name_ar` |
| `drugs` | `id, trade_name_en, trade_name_ar, active_ingredient, manufacturer, group_id, route, form`**+**`, strength_hint, price_egp, status`**+** |
| `ingredients`**+**, `drug_ingredients`**+** | `ingredients(id, name)`, `drug_ingredients(ingredient_id, drug_id)`: spec A.3.3, so all brands of one ingredient can be listed. |
| `lab_tests` | `id`**+**`, loinc_code, name_en, short_name, name_ar, aliases, loinc_class, priority`**+**`, order_rank`**+** |
| `radiology` | `id`**+**`, loinc_code, name_en, name_ar, modality, region, aliases, modality_subtype`**+**`, focus`**+**`, priority`**+** |
| `modalities`**+** | `code, name_en, name_ar`: labels for filter chips (A.5.3). |
| `fts_drugs, fts_labs, fts_radiology` | FTS5 indexes (see below). |

- `drugs.trade_name_en` is the dataset's name with the availability marker removed; `status` keeps it: 0 available, 1 "(N/A)", 2 "(N/A YET)". `form` is the suggested form (A.3.5). `price_egp` is stored but must not be shown (BR-CAT13). `trade_name_ar` is a search alias only (A.3.2).
- `lab_tests.id` and `radiology.id` are the LOINC number without its dash (`58410-2` → `584102`); `loincToId` and `loincFromId` in `catalog_core` convert. They are also the FTS rowids. `name_en` and `short_name` are LOINC's LONG_COMMON_NAME and SHORTNAME, unchanged (BR-CAT10). `name_ar` comes from `aliases.csv`, else from the LOINC Arabic variant. `aliases` holds our English short names, joined with "; ". `priority`: 2 = marked priority in `aliases.csv` (common in Egypt), 1 = common in US labs (labs only), 0 = other. `order_rank` is LOINC COMMON_ORDER_RANK.
- `radiology.modality` is the Playbook modality type (XR, CT, MR, US, MG, DXA, NM, RF, PT, PT+CT, NM.SPECT+CT). `region` is the region imaged (Chest, Abdomen, Pelvis, Head, Neck, Breast, Upper extremity, Lower extremity, Extremity, Whole Body) and `focus` the imaging focus (Knee, Spine.lumbar, Heart, Kidney ...). Several values are joined with ";". The Playbook placeholders "XXX" and "{Imaging modality}" are stored as empty.

### Search

- `fts_drugs(name, ingredient)`, `fts_labs(name, alias, related)` and `fts_radiology(name, alias, related)` are contentless FTS5 tables (`content=''`) over text already normalized by `normalizeForSearch`. Their rowid is the id of the base-table row.
- Use `ftsPrefixQuery(typed)` and the statements in `CatalogSearchSql` from `catalog_core`. Every typed word becomes a prefix query, all words must match, and results are ranked by `priority`, then bm25 with name and alias weighted above LOINC synonyms. Sections (history, specialty, other specialties, BR-CAT4) are added by the app.
- How the specialty section is matched, which the app should follow:
  - a drug is in it when its `group_id` is a `drugGroup` of the doctor's specialties or of General;
  - a lab test when its code is a `labCode`;
  - a radiology procedure when its code is a `radiologyCode`, or its `region` or `focus` contains a `radiologyRegion` value, or its `modality` is a `radiologyModality` value;
  - `route` items do not change the section; they order results inside it (BR-CAT2, Pediatrics first shows liquids and suppositories).

## Mapping files (`mappings/`)

All are UTF-8 CSV, edited by people and checked by the builder.

| File | Columns | Notes |
|---|---|---|
| `groups.csv` | `id, name_en, name_ar` | The 63 groups of A.3.6 plus **10 added**, because large parts of the data had no fitting group: `topical_analgesics` (massage creams and gels; 577 products), `joint_care` (glucosamine, collagen; 317), `vaginal_care` (washes, douches; 309), `infant_nutrition` (milk formulas; 157), `hematology` (EPO, clotting factors, hemostatics; 133), `venous_hemorrhoids` (diosmin-type venotonics, hemorrhoid products; 110), `digestive` (digestive enzymes, IBD drugs; 104), `dementia` (memantine, donepezil, rivastigmine; 85), `renal` (phosphate and potassium binders, calcimimetics; 38), `obstetric` (tocolytics, oxytocin, labor inducers; 33). |
| `class-to-group.csv` | `raw_drug_class, group_id, route` | One row for **each of the 2,499 distinct classes** in the 2026-06 dataset, largest first, plus 88 rows where `route` is set: the same class often covers tablets, eye drops and creams, so for example `GLUCOCORTICOID` is `corticosteroids`, but `topical_steroids` for route TOPICAL and `eye` for route EYE. A row with a route wins over the row without. A class that is not listed goes to `other` and is printed by the build. |
| `form-tokens.csv` | `token, form, route` | Words of the trade name that give the form (A.3.5), built from the most frequent words in the real names. A token can be several words ("EYE DROPS"). With `route`, the row only applies to that route (DROPS on route EYE → Eye drops). The trade name is read as runs of letters, so "F.C.TABS." gives TABS and "30TABS" gives TABS; the last form word in the name wins. |
| `route-to-form.csv` | `route, default_form` | Used when no token matches. The data has 13 routes, 3 more than the spec table: EAR → Ear drops; VAGINAL and MOUTH give no form because they mix washes, pessaries and gels. |
| `aliases.csv` | `type, code, alias_en, name_ar, priority` | Our names (BR-CAT10, A.4.4, A.4.5): 228 rows for 122 lab tests and 48 radiology procedures, covering the tests and procedures named in the 6.9 profile table for the seeded specialties and the A.4.4/A.4.5 examples. Several rows per code are allowed; the first Arabic name becomes `name_ar` and the rest are search words. Every code was checked against LOINC 2.83, and the builder checks again. |
| `radiology-terms.csv`**+** | `kind, value, name_en, name_ar, search_terms` | English and Arabic words added to the search index of every procedure with that Playbook modality, subtype, region or focus, so «سونار بطن» finds "US Abdomen" and «رنين ركبة» finds knee MRI. `modality_focus` rows apply to a pair: `US/Heart` adds "echo" and «إيكو» to heart ultrasound only. The `modality` rows fill the `modalities` table (A.5.3). |
| `specialty-profiles.csv` | `specialty_name_en, item_type, value` | Seed for the backend's `SpecialtyProfileItems` (AD19). `specialty_name_en` is a seeded `Specialties.NameEn` or `General`. `item_type` is one of `drugGroup, labCode, radiologyRegion, radiologyModality, radiologyCode, route` (the database CHECK constraint). 402 rows. |

### How the class mapping was made

1. Exported every distinct `drug_class` with its count and read all 2,499.
2. Wrote ordered keyword rules (first match wins) to propose a group for each, then reviewed every group's list and fixed wrong matches. The rules were a one-off aid and are not kept: `class-to-group.csv` is the source of truth.
3. Classes that are wrongly labelled in the dataset were mapped by their actual ingredients, checked in the data:
   - `ANTIPLATLET.DIRECT FACTOR XA INHIBITOR` (rivaroxaban, apixaban) → `anticoagulants`;
   - `DOPAMINE D2 AGONIST` (it is memantine) → `dementia`;
   - `ANTICHOLINESTERASE` (rivastigmine) → `dementia`;
   - `SEXUAL TONIC` (sildenafil, tadalafil) → `erectile`;
   - `STERILE SOLUTION` (IV glucose and saline) → `iv_fluids`;
   - `ANTI-RHEUMATIC.OSTEOARTHRITIS.ANABOLIC AGENTS` (glucosamine, collagen) → `joint_care`;
   - `ANTIHYPERTENSIVES.HAIR REGROWTH.VASODILATOR AGENTS` (topical minoxidil) → `skin_other`;
   - `IMMUNOSUPPRESSIVE AGENT...PYRIMIDINE SYNTHESIS INHIBITOR` (leflunomide) → `dmards`;
   - `HYPOTHALMIC HORMONES.SOMATOSTATIN ANALOGUES` (octreotide) → `other`.
4. **Ingredient fallback.** A product whose class maps to `other` (the junk classes `.` and empty, generic ones such as `CREAM`) takes the group of the other products with exactly the same active ingredients, if at least two of them have a real group and two thirds agree. Same-route products are tried first. 44 products were placed this way; the class report marks them `ingredientFallback`.

## Decisions and differences from the spec

1. **Products marked `(CANCELLED)`, `(ILLEGAL IMPORT)` or `(WITHDRAWAL)` are left out** (355), so doctors are not offered them. `--keep-withdrawn` keeps them. The dataset writes these markers, and `(N/A)` / `(N/A YET)`, inside the trade name; the builder moves them to `status` so they are never printed on a prescription.
2. **Strength parser (A.3.4).** The spec's pattern also matches pack sizes: "SUSP. 120 ML" gives "120 ML" and "CREAM 50 GM" gives "50 GM". On the real data that is about 4,800 wrong volumes and many tube sizes. The parser in `catalog_core` leaves those empty ("never guess"): a volume only counts after a slash ("250MG/5ML"), and grams of creams, gels, ointments, soaps and powders are taken as pack sizes. Units must be whole words ("30 GUMMIES" is not 30 G). Coverage is 52% of products; many of the rest (cosmetics, supplements) have no strength in the name.
3. **Arabic skeleton search (addition to A.6).** The dataset spells trade names phonetically: Panadol is «بانادول», while doctors type «بنادول», so AC-18 failed with the A.6 normalization alone. Arabic words are also indexed and searched by their "skeleton", with ا و ي ء ؤ ئ dropped after the first letter (both become «بندل»). Skeletons shorter than 3 letters are not used. The same code (`arabicSkeleton` in `catalog_core`) runs in the builder and the app.
4. **Other normalization additions (A.6).** A space is inserted between digits and letters ("500MG" = "500 MG"). Persian ی/ک and Persian digits are mapped, the Arabic decimal separator ٫ becomes ".", and all Arabic combining marks (U+064B–U+065F) are removed, not only U+064B–U+0652.
5. **No FTS prefix index, `detail=full`.** The brief asked for prefix indexes. Measured on the real file, `prefix='2 3'` added about 45% to the download (gzip 5.6 → 8.1 MB at the time) and made no measurable difference to search time: two-letter-or-longer queries took under 15 ms either way, and one-letter queries are slow because of ranking, not lookup. Prefix matching itself ("ator", "omep") works without an index. `detail=column` would have saved 1.3 MB more, but on a contentless table it turns bm25 off (all scores 0), so results came back unranked. To add a prefix index later, change `CatalogSchema.ftsOptions` and bump the schema version.
6. **LOINC synonyms (RELATEDNAMES2) are indexed without LOINC axis noise.** Words such as "Point in time", "Random", "Qnt", "SerPl" and "Ordinal" were in tens of thousands of terms and took about half of the lab index. Nobody types them. The list is `relatedStopWords` in `lib/src/catalog.dart`.
7. **Third-party LOINC content is left out.** Six lab terms carry an `EXTERNAL_COPYRIGHT_NOTICE` (LOINC licence 10.2): 85624-5, 85625-2, 85626-0, 85904-1, 85905-8, 88863-6.
8. **Radiology `region` alone is not enough for specialties.** The Playbook has no "Spine" region: spine studies are region Neck, Chest or Abdomen with focus `Spine.cervical`, `Spine.thoracic` or `Spine.lumbar`. So profile `radiologyRegion` values match either `region` or `focus` (see Search above). Echocardiography is modality US with focus Heart; Doppler is a modality subtype. DXA is a modality type.
9. **The 6.9 profile table has two specialties the database does not seed**: Rheumatology and Oncology. Their rows are not in `specialty-profiles.csv`.

## Specialty profiles

Built from the 6.9 table, mapped onto the 19 seeded specialties and General. Where the table says a whole family, I used the closest groups; codes are in `specialty-profiles.csv`.

**Not in the 6.9 table, my choices (need a doctor's review):**

- **General Surgery:**
  - groups: antibiotics, analgesics, NSAIDs, local anesthetics, venotonics and hemorrhoids, other skin preparations (wound care), stomach protection, antiemetics;
  - labs: CBC, PT, INR, aPTT, fasting and random sugar, creatinine, liver function, blood group, HBsAg, HCV antibody, HIV antibody;
  - radiology: abdominal ultrasound, CT abdomen and pelvis (with and without contrast), chest X-ray, breast ultrasound, mammography, leg vein Doppler, neck ultrasound; region Abdomen.
- **Physiotherapy:**
  - groups: NSAIDs, muscle relaxants, massage products, joint supplements, analgesics;
  - labs: vitamin D, calcium, ESR, CRP;
  - radiology: X-ray and MRI of the lumbar and cervical spine and knee; regions limbs and spine.
- **General Practice:**
  - groups: analgesics, NSAIDs, antibiotics, stomach protection, antihistamines, cold and flu, cough, antispasmodics, antiemetics, antidiarrheals, ORS, vitamins, iron, antiparasitics, antihypertensives, oral antidiabetics;
  - labs: CBC (with and without differential), ESR, CRP, fasting, random and post-meal sugar, HbA1c, urine and stool analysis, liver and kidney function, lipid profile, TSH;
  - radiology: chest X-ray, abdominal and pelvic ultrasound.
- **General** (BR-CAT3 lists the families but not the items):
  - groups: analgesics, NSAIDs, antibiotics, stomach protection, vitamins, supplements, antihistamines;
  - labs: CBC (with and without differential), ESR, CRP, fasting sugar, urine analysis.

**Added to the 6.9 rows** (the table names a family that the data splits, or the data needed it):

- Pediatrics: iron, cough, cold and flu, antidiarrheals, infant formula.
- Obstetrics and Gynecology:
  - groups: obstetric drugs (the table's "tocolytics"), vaginal care;
  - labs: urine pregnancy test, AMH;
  - radiology: breast ultrasound, region Pelvis and Breast, modality MG.
- Orthopedics: joint supplements, massage products, analgesics.
- Dermatology: other skin preparations, cosmetics; fungal culture.
- ENT: cough.
- Neurology and Psychiatry: dementia drugs. Psychiatry also gets the valproate level.
- Urology: erectile dysfunction drugs, free PSA, semen analysis, creatinine, bladder and scrotal ultrasound.
- Gastroenterology and Hepatology: antidiarrheals, digestive enzymes and IBD drugs, liver enzymes, bilirubin, albumin, PT/INR, AFP, H. pylori antibody, liver ultrasound.
- Endocrinology and Diabetes: osteoporosis drugs, post-meal sugar, FT3, anti-TPO, vitamin D, PTH, prolactin, urine albumin/creatinine.
- Nephrology:
  - groups: kidney failure drugs (the table's "phosphate binders"), hematology (the table's "erythropoietin");
  - labs: sodium, potassium, urine analysis, calcium, phosphorus, PTH, CBC.
- Cardiology: troponin T, PT, sodium and potassium, carotid Doppler, heart and coronary focus.

**Aliases that point at the closest LOINC term, not an exact match** (A.4.4 "local packages"):

- «وظائف كلى» / KFT → Renal function 2000 panel (24362-6), which contains more than the usual Egyptian urea + creatinine.
- Stool analysis → Ova and parasites by light microscopy (10704-5). LOINC has no general "stool analysis" panel.
- HRCT chest → CT chest without contrast (29252-4).
- X-ray nasopharynx → XR Neck lateral (24843-5).
- Periapical X-ray → XR Teeth views (115585-2).
- TORCH → the six Toxoplasma, Rubella and CMV IgG/IgM tests.

An admin custom item (BR-CAT9) may fit some of these better.

## What needs a doctor's review

Spec A.1 step 4 and A.8:

1. `groups.csv`: the group names in both languages, and the 10 added groups.
2. `class-to-group.csv`: every class, starting with the largest. The review aid `out/catalog-v1-drug-classes.csv` lists each class with its group and product count. Check especially:
   - the reclassified classes listed above;
   - anti-edema enzymes (trypsin, bromelain) and alpha-amylase syrups, mapped to `nsaids`;
   - cerebral circulation enhancers (piracetam, citicoline), mapped to `neuropathic`;
   - probiotics, mapped to `antidiarrheals`;
   - GLP-1 injections (semaglutide, tirzepatide), in `antidiabetics_oral`;
   - prolactin inhibitors (cabergoline), mapped to `fertility`;
   - ADHD drugs, modafinil, general anesthetics, contrast agents and myasthenia drugs, left in `other`.
3. `specialty-profiles.csv`: all of it, especially General Surgery, Physiotherapy, General Practice and General.
4. `aliases.csv` and `radiology-terms.csv`: the Arabic names and the codes chosen. Note that «هرمون الغدة الدرقية» for TSH is the spec's example; «الهرمون المنبه للغدة الدرقية» is also there as a search alias.
5. A spot check of 50 random medicines (group, form, strength) and the top 100 lab and radiology aliases (A.8).

## Licensing checklist (A.7)

- [ ] **About screen** shows the LOINC notice, verbatim (LOINC licence section 10.1, BR-CAT14):
  > This material contains content from LOINC (http://loinc.org). LOINC is copyright © Regenstrief Institute, Inc. and the Logical Observation Identifiers Names and Codes (LOINC) Committee and is available at no cost under the license at http://loinc.org/license. LOINC® is a registered United States trademark of Regenstrief Institute, Inc.
- [ ] **About screen** credits the RSNA Playbook / RadLex (licence, "Required Attributions" E):
  > The LOINC/RSNA Radiology Playbook contains content from RadLex® (http://www.radlex.org), copyright © 2005-2025, The Radiological Society of North America, Inc., available at no cost under the license at https://www.rsna.org/uploadedFiles/RSNA/Content/Informatics/RadLex_License_Agreement_and_Terms_of_Use_V2_Final.pdf.
- [ ] **About screen** credits the Egyptian drug dataset (CC0, so optional but asked by A.3.1): "Medicine data: Egyptian Drug Database by karem505 (CC0)."
- [x] LOINC source files are not in a repository (`sources/` is ignored; the test fixture is synthetic).
- [x] LOINC names are not edited: `name_en` and `short_name` are LONG_COMMON_NAME and SHORTNAME as published. Our names are in `aliases.csv` and separate columns.
- [x] Terms with third-party copyright (EXTERNAL_COPYRIGHT_NOTICE) are left out (licence 10.2).
- [x] WHO ATC/DDD data is not used anywhere.
- [ ] **Translation notice.** LOINC licence section 12 says Regenstrief must be told by email (loinc@loinc.org) *before* LOINC material is translated, and translations become theirs. Our Arabic names in `aliases.csv` may count as translations of LOINC display names. Decide whether to write to them before publishing.
- [ ] The EDA check is recorded (A.3.8): **to do**, see [`verification/2026-11-drugs-vs-eda.md`](verification/2026-11-drugs-vs-eda.md). It lists 200 random products with empty result columns; `dart run bin/eda_sample.dart` regenerates it.

## Updating

- **Medicines** (check monthly): download the CSV to `sources/drugs/<yyyy-mm>/` and record the commit hash and date above. Run the build. It lists classes missing from `class-to-group.csv`; add them (and route rows if needed) and rerun. Keep "other" under 5%.
- **LOINC** (about twice a year): unpack the release to `sources/loinc/<version>/` and run the build. Alias or profile rows that point at codes that are no longer active stop the build; fix them.
- Change `catalogSchemaVersion` in `catalog_core` when tables or columns change, so older apps refuse a file they cannot read.
