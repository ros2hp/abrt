# ComSAS PL/SQL Entry Point Packages

## Web / Member Portal Login

| Package | Description |
|---|---|
| `sas_mos_login` | Member portal (MOS) login validation and startup |
| `mil_mos_login` | Military member portal login (service/reference number auth) |
| `miex_login` | Civilian i-Estimator login (AGS number + DOB + account code) |
| `miex_access_bypass` | Staff bypass login for civilian i-Estimator |
| `milx_access_bypass` | Staff bypass login for military i-Estimator |

## Benefit Application Screens (Oracle Forms / Web)

| Package | Description |
|---|---|
| `sas_cba_first_screen` | Primary entry screen for benefit applications (`StartUp` procedure) |
| `sas_cba_summary` | Summary screen for member/PO benefit application flows |
| `sas_mos_member_statement` | Member statement retrieval from portal |
| `sas_mos_change_access` | Member access code management |
| `sas_mos_personal` | Member personal information view in portal |
| `form_actions` | Oracle Forms action router — dispatches form navigation events |
| `form_utility` | Oracle Forms field validation utilities |

## Batch Job Drivers

| Package | Description |
|---|---|
| `sas_batch` | Batch process framework; `Error`/`Heartbeat` for UNIX batch monitoring |
| `sas_statistics_driver` | Drives statistics population on schedule (`Init_Period`, `Statistics_Populate`) |
| `sas_mdc_main` | Membership Data Capture main processor — handles SED transactions |
| `sas_surc_batch` | Surcharge batch processor |
| `sas_crt_batch` | Standard letters batch processor |
| `surc_trx_file_cre_main` | MCS data extractor to ATO magnetic media format |
| `sas_fixtsfrerr_batch` | CSS revenue transfer error correction batch |
| `calcs_load` | Main calculation data loader; called by AionDS batch system |
| `calcs_load2` … `calcs_load11` | Continuation loaders split due to Oracle code-size limits |

## External System Interfaces

| Package | Description |
|---|---|
| `sas_unix_interface` | UNIX named-pipe communication (`call_unix`, `Close_Pipes`) |
| `sas_bcs_interface` / `sas_bcs_interface2-4` | BCS system integration interface |
| `sas_internet` … `sas_internet6` | Web app ↔ ComSAS data bridge (`Populate_ComSAS_Tables` etc.) |
| `sas_stlt_interface` | General statement generation interface |
| `sas_cont_stlt_interface` | Contributions statement interface |
| `sas_man_stlt_interface` | Manual grant standard letters interface |
| `sas_addic_stlt_interface` | ADDIC statement interface |
| `sas_presua_stlt_interface` / `sas_presum_stlt_interface` | Preserved UA statement interfaces |
| `sas_stlt_est_interface` | Estimate statement interface |
| `dm_send_stop_pipe` | Sends STOP signal via `DBMS_PIPE` to halt migration processes |

## Data Migration / ETL Loaders (24 packages)

| Package | Description |
|---|---|
| `dm_load_people` | Loads `DM_People_Temp` → production |
| `dm_load_payments` | Payment history migration |
| `dm_load_employment` | Employment data migration |
| `dm_load_*` (21 others) | Entity-specific loaders (tax, court orders, memberships, rollovers, etc.) |
| `dm_scan_batch_log` | Monitors and scans batch execution logs |

## Workflow Entry Points

| Package | Description |
|---|---|
| `sas_workflow_nbpo` | NBPO workflow handler — called directly by application layer |
| `sas_workflow_able_to_start` | Validates task readiness before workflow proceeds — called by nightly batch job |

## Estimation / Ready-Reckoner Entry Points

| Package | Description |
|---|---|
| `milx_ready_reckoner` | Military pension estimation calculator |
| `miep_estimates` / `miep_pres_estimates` | Civilian and preserved member estimators |
| `miep_summary` / `miec_summary` | Estimation summary screens |
| `mild_benefit_summary` | Military benefit summary display |

---

**Summary:** ~60 entry point packages across six categories. The main external seams are the **MOS/i-Estimator web portals**, **Oracle Forms** (`form_actions`), the **AionDS batch system** (`calcs_load*`, `sas_batch`), **UNIX named pipes** (`sas_unix_interface`), **BCS integration** (`sas_bcs_interface*`), and the **data migration ETL layer** (`dm_load_*`).
