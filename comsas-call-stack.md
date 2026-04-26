# ComSAS PL/SQL Entry Point Call Stacks

---
### Key Findings
                                                                                      
  The file covers all 93 packages across the 7 functional groups, with each package showing:                                                                            
  - Inbound callers — which packages call into it                                                                                                                                    
  - Outbound call tree — every significant outbound call, internal delegation, and table interaction                                                                                 
  - Summary — one-line description of the package's role                                                                                                                             
                                                                                                                                                                                     
  Key observations that emerged from the analysis:                                                                                                                                 
  - SAS_CBA_HTML is a universal dependency across nearly all web-facing packages — it's the HTML template engine underpinning the entire web portal                                  
  - DBMS_PIPE is the inter-process communication backbone used by both the BCS mainframe interface and all data migration loaders                                                    
  - The workflow system (SAS_WORKFLOW + task handlers) uses dynamic PL/SQL dispatch via DYN_PROCEDURE and function references stored in WORKFLOW_ITEMS, making it a plugin-style     
  engine                                                                                                                                                                             
  - The 24 DM_LOAD_* packages split cleanly into two structural patterns (simple row-by-row vs. batch-controlled with DM_Batch_Headers_Temp sequence numbers 1–10)
  - Of the 89 packages documented, 57 are true entry points (invoked directly from outside PL/SQL — web server, Oracle Forms, batch scheduler, AionDS, or migration control scripts)
  and 32 are internal services called only by other PL/SQL packages within the database
  - The 32 internal services are where the core business logic is concentrated: the workflow engine (SAS_WORKFLOW + task handlers), the BCS mainframe communications layer
  (SAS_BCS_INTERFACE/3/4), the pension calculation chain (CALCS_LOAD through CALCS_LOAD11), and the INET/CBA ETL cluster (SAS_INTERNET3–6) — all shared engines that multiple
  entry points delegate into
  - The 57 entry points are mostly thin coordinators: they validate input, render HTML, drive a batch cursor loop, or sequence a migration load, then delegate the substantive
  work downward to the internal services
                       

---

## Index

### Group 1 — Web / Member Portal Login

- [SAS_MOS_LOGIN](#sasmoslogin)
- [MIL_MOS_LOGIN](#milmoslogin)
- [MIEX_LOGIN](#miexlogin)
- [MIEX_ACCESS_BYPASS](#miexaccessbypass)
- [MILX_ACCESS_BYPASS](#milxaccessbypass)
- [SAS_MOS_VALIDATION](#sasmosvalidation)

### Group 2 — Benefit Application Screens / Oracle Forms

- [SAS_CBA_FIRST_SCREEN](#sascbafirstscreen)
- [SAS_CBA_SUMMARY](#sascbasummary)
- [SAS_MOS_MEMBER_STATEMENT](#sasmosmemberstatement)
- [SAS_MOS_CHANGE_ACCESS](#sasmoschangeaccess)
- [SAS_MOS_PERSONAL](#sasmospersonal)
- [FORM_ACTIONS](#formactions)
- [FORM_UTILITY](#formutility)
- [SAS_MEMBER_ADDRESS](#sasmemberaddress)

### Group 3 — Batch Job Drivers

- [SAS_BATCH](#sasbatch)
- [SAS_STATISTICS_DRIVER](#sasstatisticsdriver)
- [SAS_MDC_MAIN](#sasmdcmain)
- [SAS_SURC_BATCH](#sassurcbatch)
- [SAS_CRT_BATCH](#sascrtbatch)
- [SURC_TRX_FILE_CRE_MAIN](#surctrxfilecremain)
- [SAS_FIXTSFRERR_BATCH](#sasfixtsfrerrbatch)
- [CALCS_LOAD](#calcsload)
- [CALCS_LOAD2 … CALCS_LOAD11](#calcsload2-calcsload11)

### Group 4 — External System Interfaces

- [SAS_UNIX_INTERFACE](#sasunixinterface)
- [SAS_BCS_INTERFACE](#sasbcsinterface)
- [SAS_BCS_INTERFACE2](#sasbcsinterface2)
- [SAS_BCS_INTERFACE3](#sasbcsinterface3)
- [SAS_BCS_INTERFACE4](#sasbcsinterface4)
- [SAS_INTERNET … SAS_INTERNET6](#sasinternet-sasinternet6)
- [SAS_STLT_INTERFACE](#sasstltinterface)
- [SAS_CONT_STLT_INTERFACE](#sascontstltinterface)
- [SAS_MAN_STLT_INTERFACE](#sasmanstltinterface)
- [SAS_ADDIC_STLT_INTERFACE](#sasaddicstltinterface)
- [SAS_PRESUA_STLT_INTERFACE / SAS_PRESUM_STLT_INTERFACE](#saspresuastltinterface-saspresumstltinterface)
- [SAS_STLT_EST_INTERFACE](#sasstltestinterface)
- [DM_SEND_STOP_PIPE](#dmsendstoppipe)

### Group 5 — Data Migration / ETL Loaders

- [DM_LOAD_PEOPLE](#dmloadpeople)
- [DM_LOAD_EMPLOYMENT](#dmloademployment)
- [DM_LOAD_PAYMENTS](#dmloadpayments)
- [DM_LOAD_BEN_APPLICATIONS](#dmloadbenapplications)
- [DM_LOAD_BENEFIT_REQUESTS](#dmloadbenefitrequests)
- [DM_LOAD_CASH_PAYMENTS](#dmloadcashpayments)
- [DM_LOAD_PAYMENT_ITEMS](#dmloadpaymentitems)
- [DM_LOAD_ROLLOVER_PAYMENTS](#dmloadrolloverpayments)
- [DM_LOAD_STP_PAYMENTS](#dmloadstppayments)
- [DM_LOAD_TAX_BREAKUPS](#dmloadtaxbreakups)
- [DM_LOAD_TAX_COMPONENTS](#dmloadtaxcomponents)
- [DM_LOAD_TAX_PAYMENTS](#dmloadtaxpayments)
- [DM_LOAD_COURT_ORDERS](#dmloadcourtorders)
- [DM_LOAD_CSTM_COMMENTS](#dmloadcstmcomments)
- [DM_LOAD_LINK_MONIES](#dmloadlinkmonies)
- [DM_LOAD_MEDICALS](#dmloadmedicals)
- [DM_LOAD_MEMBERSHIP_QLFNS](#dmloadmembershipqlfns)
- [DM_LOAD_ADDITIONAL_COVER](#dmloadadditionalcover)
- [DM_LOAD_EMPLOYER_MANAGEMENT](#dmloademployermanagement)
- [DM_LOAD_NEW_AGENCIES](#dmloadnewagencies)
- [DM_LOAD_NEW_EMP_INFO](#dmloadnewempinfo)
- [DM_LOAD_PROD_QLFNS](#dmloadprodqlfns)
- [DM_LOAD_REDIRECT_AGENCY_TO](#dmloadredirectagencyto)
- [DM_LOAD_TMP_BENEFITS](#dmloadtmpbenefits)
- [DM_SCAN_BATCH_LOG](#dmscanbatchlog)

### Group 6 — Workflow Orchestrators

- [SAS_WORKFLOW](#sasworkflow)
- [SAS_WORKFLOW_APPLIN](#sasworkflowapplin)
- [SAS_WORKFLOW_APPLIN_ACTION](#sasworkflowapplinaction)
- [SAS_WORKFLOW_APPLIN_APPROVAL](#sasworkflowapplinapproval)
- [SAS_WORKFLOW_APPLIN_RECONCILE](#sasworkflowapplinreconcile)
- [SAS_WORKFLOW_APPLIN_OFFLINE](#sasworkflowapplinoffline)
- [SAS_WORKFLOW_NBPO](#sasworkflownbpo)
- [SAS_WORKFLOW_MANBP_AUTHORISE](#sasworkflowmanbpauthorise)
- [SAS_WORKFLOW_MANBP2](#sasworkflowmanbp2)
- [SAS_WORKFLOW_ABLE_TO_START](#sasworkflowabletostart)

### Group 7 — Estimation / Ready-Reckoner

- [MILX_READY_RECKONER](#milxreadyreckoner)
- [MIEP_ESTIMATES](#miepestimates)
- [MIEP_PRES_ESTIMATES](#mieppresestimates)
- [MIEP_SUMMARY](#miepsummary)
- [MIEC_SUMMARY](#miecsummary)
- [MILD_BENEFIT_SUMMARY](#mildbenefitsummary)
- [MIEC_ESTIMATES](#miecestimates)
- [MIEC_TAX](#miectax)
- [MIEC_COMMON](#mieccommon)
- [MIEX_COMMON](#miexcommon)
- [MIEX_SCREEN_COMMON](#miexscreencommon)


## Group 1 — Web / Member Portal Login

---

### SAS_MOS_LOGIN

**Outbound calls:** Yes

**Inbound callers:**
- `MIEX_LOGIN` — error fallback to login screen

**Outbound call tree:**
```
SAS_MOS_LOGIN
├─ Change_MemberLogin_Value(pAgsNo, pDob)
│    └─ SAS_CBA_HTML.ReplaceValue (×3)
├─ Confirmation_Access_Removal(pAgsNo, pDob, pAccod)
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
│    └─ SAS_MOS_COMMON.ShowButtonsFooter
├─ StartUp(pErrorNum, pAgsNo, pDob)
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    ├─ SAS_CBA_HTML.ReadFile
│    ├─ SAS_MOS_COMMON.DisplayError (conditional)
│    ├─ Change_MemberLogin_Value (internal, conditional)
│    ├─ SAS_CBA_HTML.Display
│    └─ SAS_MOS_COMMON.ShowButtonsFooter
├─ Action_Information
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    ├─ SAS_CBA_HTML.ReadFile / ReplaceValue
│    └─ SAS_CBA_HTML.Display
├─ Process_Access_Removal(pAgsNo, pDob, pAccod, pSubmit)
│    ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
│    ├─ SAS_MOS_VALIDATION.Get_Membership_Detail
│    ├─ SAS_MOS_VALIDATION.Get_Authorisation_Detail
│    ├─ SAS_MOS_VALIDATION.Get_Scheme
│    ├─ [updates Authorisations]
│    ├─ OWA_UTIL.get_cgi_env('HTTP_USER_AGENT')
│    ├─ [inserts cmos_audit]
│    ├─ Action_Information (internal)
│    └─ StartUp (internal)
└─ Process_Member_Login(pAGSNo, pDOB, pSubmit, pAccessCode)
     ├─ SAS_MOS_VALIDATION.Check_Member_Authentication
     ├─ SAS_MOS_VALIDATION.Get_Membership_Detail
     ├─ SAS_MOS_VALIDATION.Get_Scheme
     ├─ SAS_MOS_VALIDATION.Convert_Accod_To_Hex
     ├─ SAS_MOS_CHANGE_ACCESS.StartUp (conditional)
     ├─ SAS_CBA_FIRST_SCREEN.StartUp
     ├─ OWA_UTIL.get_cgi_env('HTTP_USER_AGENT')
     ├─ [queries/updates Authorisations]
     ├─ [inserts cmos_audit]
     └─ StartUp (internal, on error)
```

**Summary:** Core member authentication and login validation for the web portal, handling credential checks, access code management, and post-login routing.

---

### MIL_MOS_LOGIN

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_CBA_FIRST_SCREEN` — military member access failure redirection

**Outbound call tree:**
```
MIL_MOS_LOGIN
├─ display_header
│    ├─ MILX_COMMON.set_and_show_mos_html_header
│    └─ SAS_CBA_HTML.ReadFile / Display
├─ display_body(pService, pRefNum)
│    ├─ SAS_CBA_HTML.ReadFile
│    ├─ SAS_CBA_HTML.ReplaceValue (×2)
│    └─ SAS_CBA_HTML.Display
├─ startup
│    ├─ display_header (internal)
│    └─ display_body (internal)
├─ get_scheme(pService, pRefNum, pType)
│    ├─ [queries SAS_Globals for MIL_I_ESTIMATOR_YEAR]
│    └─ [queries ZCS_MS_Common ⟕ ZCS_MS_MSBS_Cont / ZCS_MS_DFRDB_Cont]
└─ process(pService, pRefNum, pAccessNum, pType, pScheme, pPage)
     ├─ SAS_CBA_COMMON.ResetScreenNames
     ├─ display_header / display_body (internal)
     ├─ SAS_MOS_COMMON.DisplayError (conditional)
     ├─ get_scheme (internal)
     ├─ MILX_COMMON.check_access
     └─ SAS_CBA_FIRST_SCREEN.startup
```

**Summary:** Login screen for military members with service/account number validation against MS (member statement) common tables.

---

### MIEX_LOGIN

**Outbound calls:** Yes

**Inbound callers:**
- None detected

**Outbound call tree:**
```
MIEX_LOGIN
├─ process(pAGSNo, pDOB, pAccod)
│    ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
│    ├─ SAS_MOS_LOGIN.startup (error case)
│    ├─ MIEX_SCREEN_COMMON.populate_yr
│    ├─ [queries ms_common ⟕ subquery max(ver_timestamp)]
│    ├─ [queries is_common on type='CONT']
│    ├─ SAS_CBA_FIRST_SCREEN.startup (error redirect)
│    └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
├─ accept(pAGS, pDOB, pAccess)
│    ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
│    ├─ SAS_MOS_LOGIN.startup (error case)
│    ├─ MIEX_SCREEN_COMMON.populate_yr
│    ├─ [queries ms_common, is_common]
│    ├─ SAS_CBA_FIRST_SCREEN.startup (error case)
│    ├─ [inserts cmos_audit]
│    └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
└─ continue(pAGS, pDOB, pAccess)
     ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
     ├─ SAS_MOS_LOGIN.startup (error case)
     ├─ MIEX_SCREEN_COMMON.populate_yr
     ├─ [queries ms_common, is_common]
     ├─ SAS_CBA_FIRST_SCREEN.startup (error case)
     └─ SAS_CBA_HTML.ReadFile / Display (conditional frame)
```

**Summary:** Civilian i-Estimator login with disclaimer screens, statement type/scheme determination, and member statement equity correction validation.

---

### MIEX_ACCESS_BYPASS

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called directly from web)

**Outbound call tree:**
```
MIEX_ACCESS_BYPASS
├─ startup
│    ├─ SAS_CBA_HTML.ReadFile('miex_login.html')
│    ├─ SAS_CBA_HTML.ReplaceValue('error_value', '')
│    └─ SAS_CBA_HTML.Display
├─ display_error(pError)                              [internal — error display]
│    ├─ SAS_CBA_HTML.ReadFile('miex_login.html')
│    ├─ SAS_CBA_HTML.ReplaceValue('error_value', red error HTML)
│    └─ SAS_CBA_HTML.Display
└─ process(pAgs)
     ├─ [queries Memberships ⟕ Schemes — External_ID = pAgs, status in CONT/PRES]
     ├─ SAS_Allowed(vMshpId)
     │    [used instead of Check_User_Access — different agency exclusion logic, v1.2]
     ├─ display_error (internal, on access denied)
     ├─ [queries ZCS_WXT_Globals — <SCHEME>_I_ESTIMATOR_YEAR]
     ├─ [queries ms_common — equity_correct_flg='Y', calc_status_flg not in L/R,
     │    ver_timestamp = max(ver_timestamp sub-query) for current year]
     ├─ display_error (internal, on no equity-corrected statement)
     ├─ [queries People — birth_date by per_id]
     ├─ ZCS_WCP_MOS_I_Estimator.StartUp(pAgs, DOB)
     └─ display_error (internal, exception: no_data_found)
```

**Summary:** Internal staff bypass for the civilian i-Estimator. Validates AGS number, staff access rights, and equity-corrected statement availability, then launches the i-Estimator directly without requiring the member's access code.
---

### MILX_ACCESS_BYPASS

**Outbound calls:** Yes

**Inbound callers:**
- None detected

**Outbound call tree:**
```
MILX_ACCESS_BYPASS
├─ startup
│    └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
└─ process(pService, pServiceNum)
     ├─ MILX_COMMON.is_number(pServiceNum)
     ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display (error case)
     ├─ [queries ZCS_MS_Common ⟕ ZCS_MS_DFRDB_Cont / ZCS_MS_MSBS_Cont]
     ├─ [nested exception: fallback alternate table query]
     └─ MILX_READY_RECKONER.display(pService, pServiceNum, vCode)
```

**Summary:** Internal staff bypass for military member i-Estimator with service number validation and access code retrieval.

---

---

### SAS_MOS_VALIDATION

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_MOS_LOGIN` — Encrypted_Member_Validation, Check_Member_Authentication, Get_Membership_Detail, Get_Scheme, Get_Authorisation_Detail, Convert_Accod_To_Hex, Decrypt_Accod, Encrypt_Accod
- `SAS_MOS_CHANGE_ACCESS` — Encrypted_Member_Validation, Get_Membership_Detail, Get_Authorisation_Detail, Decrypt_Accod, Encrypt_Accod, Convert_Accod_To_Hex
- `SAS_MOS_PERSONAL` — Encrypted_Member_Validation, Get_Membership_Detail, Get_Authorisation_Detail
- `SAS_MOS_MEMBER_STATEMENT` — Encrypted_Member_Validation, Get_Membership_Detail
- `MIEX_LOGIN` — Encrypted_Member_Validation
- `SAS_CBA_FIRST_SCREEN` — Encrypted_Member_Validation, Get_Membership_Detail, Get_Scheme

**Note:** Internal service — not an entry point. Primary authentication library for all MOS web packages.

**Outbound call tree:**
```
SAS_MOS_VALIDATION
├─ Encrypted_Member_Validation(pAgsNo, pDob, pAccod) → boolean
│    ├─ Convert_Accod_To_Varchar2 (internal)
│    └─ Check_Member_Authentication (internal)
├─ Check_Member_Authentication(pAGSNo, pDOB, pAccessCode, pCrypType default 'D') → number
│    ├─ Get_Membership_Detail (internal)
│    ├─ Get_Authorisation_Detail (internal)
│    ├─ Case_Failed_Access (internal, ×2)
│    ├─ Decrypt_Accod (internal, ×2)
│    ├─ SAS_CHANGED.Changed (×2)
│    ├─ SAS_Common.Is_DDMMCCYY
│    ├─ [queries People — validate birth date]
│    └─ [updates Authorisations — cancel expired temporary access code]
├─ Case_Failed_Access(pMshpID, pAuthorisation, pErrorAccess) → number
│    └─ [updates Authorisations — set status C / increment failure counters]
│         [cMaxFailedAccess=3 → 24hr suspend; cMaxTotalFailure=12 → permanent lock]
├─ Get_Membership_Detail(pAgsNo, pMemberships OUT, pErrorNumber OUT)
│    └─ [queries Memberships — External_ID = pAgsNo, status <> SUBS,
│         ordered CONT(1) PRES(2) PENS(3) NOEQ(4) VOID(5)]
├─ Get_Authorisation_Detail(pMshpId, pAuthorisation OUT, pNotFound OUT)
│    └─ [queries Authorisations — Mshp_Id = pMshpId, status not in L/C/D/X]
├─ Get_Scheme(pSchemeId) → varchar2
│    └─ [queries Schemes by id]
├─ Encrypt_Accod(pMshpID, pAccess_Code) → varchar2
│    └─ DBMS_OBFUSCATION_TOOLKIT.DESEncrypt
│         [key = membership ID rpadded to 8 bytes; code rpadded to 32 bytes]
├─ Decrypt_Accod(pMshpID, pAccess_Code) → varchar2
│    └─ DBMS_OBFUSCATION_TOOLKIT.DESDecrypt
├─ Convert_Accod_To_Hex(pAccod) → varchar2
│    └─ [inline: rawtohex(utl_raw.cast_to_raw(pAccod))]
├─ Convert_Accod_To_Varchar2(pAccod) → varchar2
│    └─ [inline: utl_raw.cast_to_varchar2(hextoraw(pAccod))]
└─ Create_New_Rows_For_Links(pFromMshp_Id, pToMshp_Id) → number
     ├─ [queries Authorisations — check if target already has auth record]
     ├─ Get_Authorisation_Detail (internal)
     ├─ Decrypt_Accod (internal)
     ├─ Encrypt_Accod (internal)
     ├─ [updates Authorisations — set status = L for source membership]
     ├─ [queries Auth_Seq.NextVal]
     └─ [inserts Authorisations — new row for target membership]
```

**Summary:** Authentication and access code management library for the MOS web portal. Validates AGS number, date of birth, and encrypted access code; enforces account lockout rules; provides DES encrypt/decrypt and hex conversion utilities for safe web transmission of access codes.

## Group 2 — Benefit Application Screens / Oracle Forms

---

### SAS_CBA_FIRST_SCREEN

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_MOS_LOGIN` — post-login navigation
- `SAS_MOS_MEMBER_STATEMENT` — statement access completion
- `SAS_MOS_CHANGE_ACCESS` — after access code change
- `MIEX_LOGIN` — i-Estimator error fallback
- `SAS_MOS_PERSONAL` — personal details update completion
- `MIL_MOS_LOGIN` — military member routing

**Outbound call tree:**
```
SAS_CBA_FIRST_SCREEN
├─ CheckUser() → boolean
│    └─ [queries User_Details for authorisation]
└─ StartUp(pMessage, pAGS, pDoB, pAccess, pService, pType)
     ├─ CheckUser (internal)
     ├─ SAS_CBA_PO_CHANGE_PASSWORD.StartUp (password expiry)
     ├─ MILX_COMMON.Get_Scheme(pService, pAgs, pType)
     ├─ MILX_COMMON.check_access
     ├─ MIL_MOS_LOGIN.StartUp (military failure)
     ├─ MILX_COMMON.Set_And_Show_MOS_HTML_Header
     ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display (multiple)
     ├─ SAS_CBA_COMMON.ResetScreenNames
     ├─ SAS_CBA_COMMON.GetContextInformation
     ├─ SAS_CBA_COMMON.DisplayContextInformation
     ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
     ├─ SAS_MOS_LOGIN.StartUp (member validation failure)
     ├─ SAS_MOS_VALIDATION.Get_Membership_Detail
     ├─ SAS_MOS_VALIDATION.Get_Scheme
     ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
     ├─ SAS_MOS_COMMON.DisplayError (conditional)
     ├─ SAS_CBA_COMMON.DisplayError (conditional)
     ├─ [queries User_Qualifications ⟕ Code_Values]
     ├─ [queries MS_Common for statement years]
     ├─ ZCS_ECP_QAGENCY(vMshp.ID, vMshp.Sch_ID)
     └─ SAS_CBA_HTML.ReadFile / ReplaceValue (dynamic menu construction)
```

**Summary:** First-screen main menu routing for all user types (ComSuper staff, web members, military members) with user authorisation, menu qualification checks, and statement/i-Estimator availability validation.

---

### SAS_CBA_SUMMARY

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called directly from web forms)

**Outbound call tree:**
```
SAS_CBA_SUMMARY
├─ InstStartup(pHeaderScreenName, ..., pButton)
│    ├─ SAS_CBA_COMMON.ResetScreenNames
│    ├─ SAS_CBA_COMMON.VerifyApplication(pPIN, pAppliD)
│    ├─ SAS_CBA_COMMON.GetContextInformation
│    ├─ SAS_CBA_COMMON.DisplayContextInformation
│    └─ InstDisplay (internal)
├─ InstDisplay
│    ├─ SAS_CBA_HTML.ReadFile
│    ├─ SAS_CBA_COMMON.ReplaceScreenNames
│    ├─ SAS_CBA_HTML.ReplaceValue / Display
│    └─ SAS_CBA_COMMON.DisplayButtonAndFooter
├─ MemMenuStartup
│    └─ SAS_CBA_MEM_COMMON.StartUpIdentify
├─ POMemMenuStartUp / POMenuStartUp
│    └─ SAS_CBA_PO_COMMON.StartUpIdentify
├─ DisplaySummaryCommon
│    ├─ SAS_CBA_HTML.ReadFile
│    ├─ SAS_CBA_COMMON.ReplaceScreenNames
│    ├─ [queries Code_Values for EXIT_TYPE description]
│    └─ SAS_CBA_HTML.ReplaceValue / Display
├─ DisplayPostalAddress
│    ├─ [queries Cba_Postal_Addresses for type='P']
│    └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
├─ DisplayMaritalStatus
│    ├─ DisplaySundryHeader (internal)
│    ├─ GetSpouse (internal)
│    └─ SAS_CBA_HTML operations
├─ DisplaySpouseClaimant
│    ├─ SAS_CBA_HTML operations
│    └─ [loops Cba_People for children with PerTyp_Code='CHILD']
└─ DisplayNonMemberClaimant
     ├─ DisplayExecutor (internal)
     ├─ DisplaySpouseClaimant (internal)
     ├─ DisplayGuardian (internal)
     └─ DisplayOrphanClaimant (internal)
```

**Summary:** Benefit application summary screen rendering claimant/spouse/dependent details, postal address, marital status, and member comments.

---

### SAS_MOS_MEMBER_STATEMENT

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called directly from web forms)

**Outbound call tree:**
```
SAS_MOS_MEMBER_STATEMENT
├─ User_Exist() → boolean
│    └─ [queries User_Details]
├─ User_Can_Access(pMshpId) → boolean
│    ├─ [queries Employment_Record for agency/paycentre]
│    └─ [queries User_Agency_Restrictions cursor]
├─ Startup(pAgsNo, pDob, pAccod, pErrorNumber)
│    ├─ SAS_MOS_VALIDATION.Get_Membership_Detail
│    ├─ SAS_MOS_VALIDATION.Get_Scheme
│    ├─ SAS_MOS_LOGIN.StartUp (error redirect)
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
│    ├─ SAS_MOS_COMMON.DisplayError (conditional)
│    ├─ [cursor loop: queries ms_common with equity_correct_flg='Y']
│    └─ SAS_MOS_COMMON.ShowButtonsFooter
└─ Process(pHeaderScreenName, ..., pAction)
     ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
     ├─ SAS_MOS_LOGIN.StartUp (validation failure)
     ├─ SAS_MOS_VALIDATION.Get_Membership_Detail
     ├─ SAS_MS_COMMON.Get_MS_Type(vMember.Id, pStatementYr)
     ├─ User_Can_Access(vMember.Id)
     ├─ [queries ms_common for statement details]
     ├─ [inserts cmos_audit on first page]
     ├─ SAS_CBA_FIRST_SCREEN.StartUp (cancel)
     ├─ DBMS_SQL.open_cursor / parse / execute / close_cursor
     ├─ [dynamic SQL: SAS_Internet_RIS_YYYY_YYYY.Member_Details]
     └─ SAS_MOS_LOGIN.StartUp (exception: no_data_found)
```

**Summary:** Member statement screen selector displaying available statement years and invoking year-specific statement packages dynamically.

---

### SAS_MOS_CHANGE_ACCESS

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_MOS_LOGIN` — forced mandatory access code change

**Outbound call tree:**
```
SAS_MOS_CHANGE_ACCESS
├─ Agency_Is_ComSuper(pMshpId) → boolean
│    ├─ [queries Employment_Record]
│    └─ [queries Agencies]
├─ StartUp(pAgsNo, pDob, pAccod, pErrorNum, pMustChangeAccod)
│    ├─ SAS_MOS_VALIDATION.Get_Membership_Detail / Get_Scheme
│    ├─ SAS_MOS_LOGIN.StartUp (error redirect)
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
│    └─ SAS_MOS_COMMON.ShowButtonsFooter
├─ Show_Prize_WebPage(pAgsNo, pDob, pAccod)
│    ├─ SAS_MOS_VALIDATION.Get_Membership_Detail / Get_Scheme
│    ├─ SAS_MOS_LOGIN.StartUp (error redirect)
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    └─ SAS_CBA_HTML operations
├─ Process_Prize(pAgsNo, pDob, pAccod, pPrize)
│    ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
│    ├─ SAS_MOS_VALIDATION.Get_Membership_Detail / Get_Authorisation_Detail
│    ├─ Agency_Is_ComSuper (internal)
│    ├─ SAS_CBA_FIRST_SCREEN.StartUp
│    └─ [updates Authorisations.Prize]
└─ Process(pAgsNo, ..., pMustChangeAccod, pSubmit)
     ├─ SAS_CBA_FIRST_SCREEN.StartUp (cancel)
     ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
     ├─ SAS_MOS_VALIDATION.Get_Membership_Detail / Get_Authorisation_Detail
     ├─ SAS_COMMON.Is_Integer(pNewCode)
     ├─ StartUp (internal, validation errors)
     ├─ SAS_MOS_VALIDATION.Decrypt_Accod / Encrypt_Accod / Convert_Accod_To_Hex
     ├─ Agency_Is_ComSuper (internal)
     ├─ Show_Prize_WebPage (internal, conditional)
     ├─ OWA_UTIL.get_cgi_env('HTTP_USER_AGENT')
     ├─ [updates Authorisations]
     └─ SAS_CBA_FIRST_SCREEN.StartUp (success)
```

**Summary:** Member access code change with optional prize selection, encryption/decryption, and ComSuper agency restriction checks.

---

### SAS_MOS_PERSONAL

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called directly from web forms)

**Outbound call tree:**
```
SAS_MOS_PERSONAL
├─ Get_Email_Address(pPerId) → varchar2
│    └─ [queries Emails with valtyp_code='V']
├─ Setup_Personal_Detail_Sec1-5(...)
│    └─ SAS_CBA_HTML.ReplaceValue (multiple)
├─ Show_Personal_Detail_Page(...)
│    ├─ SAS_MOS_VALIDATION.Get_Scheme
│    ├─ SAS_MOS_COMMON.Set_And_Show_MOS_HTML_Header
│    ├─ SAS_CBA_HTML.ReadFile / Display
│    ├─ SAS_MOS_COMMON.Display_Multiple_Errors (conditional)
│    ├─ Setup_Personal_Detail_Sec1-5 (internal)
│    └─ SAS_MOS_COMMON.ShowButtonsFooter
├─ StartUp(pAgsNo, pDob, pAccod)
│    ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
│    ├─ SAS_MOS_LOGIN.StartUp (validation failure)
│    ├─ SAS_MOS_VALIDATION.Get_Membership_Detail / Get_Authorisation_Detail
│    ├─ Get_Email_Address (internal)
│    ├─ SAS_MEMBER_ADDRESS.Get_Address
│    ├─ SAS_EMPLOYER_ADDRESS.Get_Address (conditional)
│    ├─ [queries Agencies for agency name]
│    └─ Show_Personal_Detail_Page (internal)
└─ Process(pAgsNo, ..., pChkbox)
     ├─ SAS_MOS_VALIDATION.Encrypted_Member_Validation
     ├─ SAS_MOS_LOGIN.StartUp (validation failure)
     ├─ SAS_MOS_VALIDATION.Get_Membership_Detail / Get_Authorisation_Detail
     ├─ Get_Email_Address / SAS_MEMBER_ADDRESS.Get_Address / SAS_EMPLOYER_ADDRESS.Get_Address
     ├─ SAS_APPLICATION_ERROR.Initialise / Message (validation errors)
     ├─ SAS_CHANGED.Changed (field comparisons)
     ├─ SAS_MEMBER_ADDRESS.Update_Address
     ├─ SAS_MEMBER_EMAIL.Update_Email (if changed)
     ├─ [updates Authorisations]
     ├─ OWA_UTIL.get_cgi_env('HTTP_USER_AGENT')
     ├─ [inserts cmos_audit]
     └─ SAS_CBA_FIRST_SCREEN.StartUp (success/no-change)
```

**Summary:** Member personal details management (email, home address, statement delivery, email notifications) with validation, change tracking, and audit logging.

---

### FORM_ACTIONS

**Outbound calls:** No

**Inbound callers:**
- None detected (called directly from Oracle Forms)

**Outbound call tree:**
```
FORM_ACTIONS
└─ get_form_actions(pForm) → tFormActions
     └─ [cursor loop: queries Form_Actions where Form_Name = pForm OR 'ALL']
```

**Summary:** Retrieves form action configurations from the Form_Actions table for dynamic Oracle Forms navigation routing.

---

### FORM_UTILITY

**Outbound calls:** No

**Inbound callers:**
- None detected (called directly from Oracle Forms)

**Outbound call tree:**
```
FORM_UTILITY
└─ Found_Illegal_Character(pName, pErrorMsg) → BOOLEAN
     └─ [character validation: alphabetic start, hyphen/space/apostrophe rules,
         consecutive special character check]
```

**Summary:** Form field name validation utility enforcing alphabetic start and allowed special character rules for Oracle Forms input.

---

---

### SAS_MEMBER_ADDRESS

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_MOS_PERSONAL` — Get_Address (home and employer addresses), Update_Address (on personal details change)

**Note:** Internal service — not an entry point. Used by all ComSAS schemes for member address management.

**Outbound call tree:**
```
SAS_MEMBER_ADDRESS
├─ UnDeliverable_Address(pAddressLine1, pAddressLine2, pAddressCity, pAddressPostCode) → boolean
│    ├─ [queries SAS_Text_Globals — CORPORATE_ENTITY_NAME]
│    └─ [queries Addresses — owner_id=50000, owner_type='CONTACT', addrtyp_code='P', valtyp_code='V']
│         [returns true if both lines blank OR address matches corporate address]
│         [keyword pattern matching removed in v1.11 T31569 — code retained as comments]
├─ Get_Address(pPerID, pType, pAddress OUT)           [overload 1 — with type]
│    ├─ SAS_Address_Exists
│    └─ UnDeliverable_Address (internal, if address found)
├─ Get_Address(pPerID, pAddress OUT)                  [overload 2 — postal default]
│    └─ Get_Address (internal, delegates with cPostal='P')
├─ Update_Address(pPerID, pType, pAddress IN OUT, pUser default USER)  [overload 1]
│    ├─ [queries Addresses — FOR UPDATE, owner=pPerID/PERSON/pType, end_date is null]
│    ├─ [updates Addresses — ValTyp_Code: V→NV, others retain; End_Date=sysdate]
│    │    [v1.13 T32154: non-V validity types now preserved on close]
│    └─ [inserts Addresses — ValTyp_Code='V', Start_Date=sysdate, DPID null unless QAS_BATCH]
├─ Update_Address(pPerID, pAddress IN OUT, pUser default USER)         [overload 2]
│    └─ Update_Address (internal, delegates with cPostal='P')
├─ SAS_Assign_Statement_Delivery(pMshp_Id) → varchar2
│    ├─ [queries Memberships — get per_id by mshp_id]
│    ├─ SAS_Address_Exists (×2 — checks postal 'P' then residential 'R', valtyp='V')
│    └─ [returns 'H' (Home) if valid address found; 'A' (Agent) otherwise]
└─ HasPostalAddress(pPerID) → boolean
     └─ Get_Address (internal — returns Successful flag from postal Get_Address)
```

**Summary:** Generic address management library for all ComSAS schemes. Retrieves and validates member postal/residential addresses, updates using end-date versioning, determines statement delivery mode (Home vs Agent), and identifies undeliverable addresses.

## Group 3 — Batch Job Drivers

---

### SAS_BATCH

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_BCS_INTERFACE4` — Poll_Mainframe error reporting

**Outbound call tree:**
```
SAS_BATCH
├─ PACKAGE GLOBALS (defined in spec)
│    gErrorDir   varchar2  — filesystem directory for error file
│    gErrorFile  varchar2  — error filename
├─ Error(pBatch_Name, pSeverity, pMessage)
│    ├─ DBMS_OUTPUT.PUT_LINE
│    ├─ ITTS.SidName                  → SYS_CONTEXT('userenv','DB_NAME')
│    │    [resolves env subdir: dev/dev2/datacap get subdirectory; test/prod do not]
│    ├─ UTL_FILE.FOpen(vErrorDir, gErrorFile, 'a')  [falls back to 'w' on first run]
│    ├─ UTL_FILE.PUT_LINE(vFile, vErrorLine)
│    ├─ UTL_FILE.FFlush(vFile)
│    └─ UTL_FILE.FClose(vFile)
├─ Heartbeat                          [called by DBMS_JOB scheduler externally]
│    ├─ [queries BATCH_PROCESSES ⟕ ALL_JOBS on Job_ID]
│    └─ SAS_BATCH.Error(...)          [per job: WARNING or ERROR]
│         [suppressed before 5 AM to avoid spurious post-backup alerts]
└─ ResetErrorFile                     [dev/test utility — truncates error log]
     ├─ ITTS.SidName
     ├─ UTL_FILE.FOpen(..., 'w')
     └─ UTL_FILE.FClose(vFile)
```

**Summary:** Thin error-reporting and job-health-monitoring utility; writes fixed-format timestamped lines to a Unix filesystem file polled by external UNIX monitoring processes.

---

### SAS_STATISTICS_DRIVER

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called by DBMS_JOB scheduler)

**Outbound call tree:**
```
SAS_STATISTICS_DRIVER
├─ Init_Period
│    └─ [calculates reporting date period from sysdate]
├─ Statistics_Populate
│    ├─ Init_Period (internal)
│    ├─ SAS_STATISTICS_ACTIVITY.Fill_Table
│    ├─ [queries Schemes table]
│    ├─ SAS_STATISTICS_ACTIVITY.Count_Activities
│    ├─ SAS_STATS_POPULATION.ContPresPopulation
│    ├─ SAS_STATS_POPULATION.UpdateABGroupTable
│    └─ SAS_NONINV_ACTIVITY_STATISTICS.NonInv_Statistics_Driver
└─ Statistics_Populate_Alt
     ├─ [queries Activity_Statistics table]
     ├─ SAS_STATISTICS_ACTIVITY.Fill_Table
     ├─ [queries Schemes table]
     ├─ SAS_STATISTICS_ACTIVITY.Count_Activities
     ├─ SAS_STATS_POPULATION.ContPresPopulation
     └─ SAS_STATS_POPULATION.UpdateABGroupTable
```

**Summary:** Drives periodic statistical collection for invoicing by populating Activity and Population statistics tables from membership activity records.

---

### SAS_MDC_MAIN

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called by AionDS batch system)

**Outbound call tree:**
```
SAS_MDC_MAIN
└─ Process(pAction in varchar2)
     ├─ [Action = 'Start']
     │    ├─ SAS_OUTPUT.Put_line
     │    ├─ SAS_MDC_QLFN.Initialise
     │    └─ SAS_MDC_DEBUG.SetDebug
     ├─ [Action = 'Transaction']
     │    ├─ SAS_MDC_COMMON.InitialiseData
     │    ├─ SAS_MDC_TRANSACTION.Get
     │    ├─ SAS_MDC_EMPLOYMENT_OTE.InsertEmploymentOTE
     │    ├─ SAS_MDC_COMMON.FindScheme
     │    ├─ SAS_MDC_DIAGNOSTIC.RaiseDiagnostic
     │    ├─ SAS_MDC_COMMON.Is_DDMMYYYY
     │    ├─ SAS_MDC_EMPLOYER.FindAgency
     │    ├─ SAS_MDC_EMPLOYER.FindSponsorship
     │    ├─ SAS_MDC_TRANSACTION.Process
     │    ├─ SAS_MDC_DIAGNOSTIC.CreateDiagnostics
     │    ├─ SAS_MDC_TRANSACTION.Tally
     │    ├─ SAS_MDC_COMMON.GetStatus
     │    ├─ SAS_MDC_TRANSACTION.Display
     │    └─ SAS_MDC_DIAGNOSTIC.Display
     └─ [Action = 'Finalise']
          ├─ SAS_OUTPUT.Put_Line
          ├─ SAS_MDC_TRANSACTION.Display
          └─ SAS_MDC_DIAGNOSTIC.Display
```

**Summary:** Main controller for Membership Data Capture, handling SED transaction validation, scheme/agency verification, and diagnostic reporting across start, transaction, and finalise phases.

---

### SAS_SURC_BATCH

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called by DBMS_JOB scheduler)

**Outbound call tree:**
```
SAS_SURC_BATCH
├─ Initialise_CDD_Array
│    └─ [queries Calcs_Paydays table]
├─ Get_Membership_Dues(pMembershipID, pSchSnm, pMakeZeds, pDuesID, pStatus)
│    ├─ [queries Memberships ∪ Employment_Record ∪ Salary_Payments ∪ Irregular_Service]
│    ├─ [inserts into Dues table]
│    └─ SAS_SURCHARGE.Get_AGS
├─ Irreg_Svc_Cleanup(pMshpID, pBenReqID, pExitDate, pAggregate, pStatus)
│    ├─ [queries Irregular_Service table]
│    ├─ [updates/deletes Calcs_CDDs table]
│    └─ SAS_SURCHARGE.Get_AGS
├─ Create_CDDs(pMshpID, pDuesID, pBenReqID, pExitDate, pAggregate, pStatus)
│    ├─ [deletes Calcs_CDDs]
│    ├─ SAS_MEMBERSHIP_FINANCIALS.Get_Birth_Date
│    ├─ [queries Dues ⟕ Memberships]
│    ├─ SAS_MEMBERSHIP_DUES.Get_Dues
│    ├─ SAS_SURCHARGE.Leap_Year
│    ├─ Irreg_Svc_Cleanup (internal)
│    └─ SAS_SURCHARGE.Get_AGS
├─ Select_CDDs(pBenReqID, pLastDate, pStatus)
│    └─ [queries Calcs_CDDs table]
└─ Get_Mshp_Years_And_Days(pMembershipID, pStartDate, pEndDate, ...)
     ├─ SAS_MEMBERSHIP_CALCS.Accumulate_One_Member
     ├─ [queries Links, Surc_Rips, Memberships, Prior_Services]
     └─ SAS_SURCHARGE.Leap_Year
```

**Summary:** Batch processor for surcharge Contribution Due Dates (CDDs) creation and membership service calculation, handling irregular service cleanups and linked membership chains.

---

### SAS_CRT_BATCH

**Outbound calls:** No

**Inbound callers:**
- None detected (called by batch scheduler)

**Outbound call tree:**
```
SAS_CRT_BATCH
├─ Load_Keys(p1 in varchar2)
│    ├─ [parses key-value string with Instr/Substr]
│    └─ [populates gKey_Values array]
├─ Load_Text(p1 in varchar2)
│    ├─ [parses text string with Instr/Substr]
│    └─ [populates gText_Values array]
└─ Submit(pLetterID in varchar2)
     ├─ [queries Letter_Params table]
     ├─ [queries Letters table]
     ├─ [inserts into Batched_Letters]
     └─ [inserts into Batched_Letter_Params]
```

**Summary:** Standard letters batch processor submitting letters to the print queue with key/text parameters parsed from formatted strings.

---

### SURC_TRX_FILE_CRE_MAIN

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called by batch scheduler)

**Outbound call tree:**
```
SURC_TRX_FILE_CRE_MAIN
├─ Initialise(pRunType, pSchemeSnm, ..., pFileLocation)
│    ├─ SAS_SURC_COMMON.Get_Record_Length
│    ├─ [queries Surc_Suppliers table]
│    ├─ SAS_SURCHARGE.Get_Financial_Year
│    ├─ SAS_SURC_COMMON.Open_Log_Files
│    └─ Restart (internal)
├─ Create_File_Header
│    ├─ UTL_FILE.Fopen / Put_Line
│    ├─ SAS_SURC_BO_COMMON.Create_Supplier_Detail_Records
│    └─ SAS_SURC_COMMON.Insert_File_Hist
├─ Process_Member_Record(pSurcConsInfo, pMemberInfo)
│    ├─ [queries Surc_Override_MCS]
│    ├─ SAS_SURC_BO_COMMON.Create_Member_Record_Manually
│    ├─ SAS_SURC_BO_COMMON.Check_for_Restricted_Agency
│    ├─ SAS_SURC_BO_COMMON.Create_Mbr_Record_Auto
│    └─ UTL_FILE.Put_Line / FFlush
├─ Close_File_Total_Record
│    ├─ SAS_SURC_COMMON.Create_File_Total
│    ├─ SAS_SURC_COMMON.Update_File_Hist
│    └─ UTL_FILE.Fclose
└─ Surc_Trx_File_Cre(pRunType, pSchemeSnm, ..., pDebug)
     ├─ DBMS_OUTPUT.ENABLE
     ├─ Initialise (internal)
     ├─ SAS_SURC_COMMON.Insert_Run_Info
     ├─ [queries ZCS_SCT_MCS_TMP ⟕ Surc_Cons]
     ├─ [queries Surc_Ame_Err_Member ⟕ Memberships ⟕ Surc_Report_Periods]
     ├─ SAS_SURC_BO_COMMON.Delete_Pre_Join_Date_Triggers
     ├─ SAS_SURCHARGE.Load_Members
     ├─ SAS_SURCHARGE.Get_Linked_To_Mshp_Status
     ├─ Process_Member_Record (loop)
     ├─ Update_Surc_AME_ERR_Table (loop)
     ├─ Close_File_Total_Record (internal)
     ├─ SAS_SURC_COMMON.Update_Run_Info
     └─ Finalise (internal)
```

**Summary:** Main driver for superannuation Member Contributions Statements (MCS) file creation in ATO magnetic media format, supporting CON, AME, ERR, and BOT run types with restart capability.

---

### SAS_FIXTSFRERR_BATCH

**Outbound calls:** Yes

**Inbound callers:**
- None detected (one-off correction batch)

**Outbound call tree:**
```
SAS_FIXTSFRERR_BATCH
├─ Build
│    ├─ [queries Item1 table]
│    └─ Insert_Tmp_Item1_Ledger (for each control page record)
├─ Get_Membership_ID / Get_Page_Type / Get_Old_Monact_ID
│    └─ [queries Memberships / Tmp_Benefits / Payments / Item1]
├─ Insert_Tmp_Item1_Ledger(...)
│    └─ [inserts into Tmp_Item1_Ledger if pAmount != 0]
├─ Update_Item1_For_Adjustment(...)
│    └─ [updates Item1 table]
├─ Update_Source_Status(pServiceNo, pStatus)
│    └─ [updates Css_Tsfr_Bcs_Ledger]
├─ Update_Activity_Total(pMonactID, pItemCode)
│    ├─ [queries Tmp_Item1_Ledger]
│    └─ SAS_MNYACT.Update_Act
├─ Insert_New_Items
│    └─ Insert_Item1 (loop)
├─ Print_Summary(...)
│    └─ DBMS_OUTPUT.PUT_LINE (formatted summary)
└─ Fix_Transfer_Err
     ├─ Build (internal)
     ├─ [queries Css_Tsfr_Bcs_Ledger]
     ├─ Get_Membership_ID / Get_Page_Type / Get_Old_Monact_ID (internal)
     ├─ SAS_MNYACT.Create_Act
     ├─ Update_Item1_For_Adjustment (internal)
     ├─ Insert_Tmp_Item1_Ledger (internal)
     ├─ Update_Source_Status (internal)
     ├─ Update_Activity_Total (internal)
     ├─ Print_Summary (internal)
     └─ Insert_New_Items (internal)
```

**Summary:** One-off batch fix for CSS revenue transfer errors using temporary ledger staging and money activity adjustments.

---

### CALCS_LOAD

**Outbound calls:** Yes

**Inbound callers:**
- `IS_INSERT_CSS` — resets gCSSDuesID global
- `PD_INSERT` — sets gCSSDuesID to null
- `SAS_SURCHARGE` — calls CDDs
- `ZCS_LCP_STLT_FLU_FORM6` — calls get_years_and_days

**Outbound call tree:**
```
CALCS_LOAD
├─ Member(pMshp_ID, pBenReq_ID, pExitDate, pClaimDate, pFinalSalary,
│          pMaxRetireAge, pMinRetireAge, pExitType)
│    ├─ SAS_Membership_Financials.Get_Birth_Date
│    ├─ SAS_Membership.Get_Join_Date (×2)
│    ├─ SAS_Membership.Get_Sch_ID
│    ├─ SAS_Mshp_Transfer.Get_Election_Details      (PSS members)
│    ├─ SAS_Membership_Dues.Get_Dues
│    ├─ SAS_Membership_Calcs.Get_Mshp_Years_And_Days (×3 — total, from 30Jun76, at 30Jun76)
│    ├─ SAS_Membership_Calcs.Get_Age_Years_And_Days  (×3 — at 65, at 59.5, prospective)
│    ├─ SAS_Membership_Calcs.Employed_In_AFP
│    ├─ get_years_and_days (internal, LWOP open-ended invalidity cases)
│    ├─ [cursor crLink5/crLink11/crAllLinks — Links table, link chain traversal]
│    ├─ [cursor crTranStatus — Links table, completed inbound transfer check]
│    ├─ [cursor c1 — Irregular_Service, irsrvtyp_code not T, end_date null]
│    ├─ [deletes Dues — temp CSS dues record gCSSDuesID]
│    └─ [inserts Calcs_Member]
├─ get_years_and_days(pFirstDate, pLastDate, pYears OUT, pDays OUT)  [internal utility]
│    └─ [inline: calendar years + day remainder between two dates]
├─ Medical(pMshp_ID, pBenReq_ID, pScheme_ID, pCalc_Date)
│    ├─ SAS_Membership_Calcs1.Get_Medical_Restriction
│    └─ [inserts CALCS_Medical — LBMStatus 'Y'/'N']
├─ Pre76(pMshp_ID, pBenReq_ID)
│    ├─ [queries Pre_76 — by Mshp_ID]
│    ├─ [queries Old_Preservations — Restriction_In_UE]
│    └─ [inserts Calcs_Pre76 — from Pre_76 source or zeroed defaults]
├─ MembXfer_Multiples(pMshp_ID, pBenReq_ID)
│    ├─ SAS_Multiple.List_Values(pMshp_ID, 'MTRA')
│    └─ [inserts Calcs_MemberXfer_Multiples]
├─ Preserved_Multiples(pMshp_ID, pBenReq_ID)
│    ├─ SAS_Multiple.List_Values(pMshp_ID, 'PRE')
│    └─ [inserts Calcs_Preserved_Multiples]
├─ Restoration_Multiples(pMshp_ID, pBenReq_ID)
│    ├─ SAS_Multiple.List_Values(pMshp_ID, 'RES')
│    └─ [inserts Calcs_Restoration_Multiples]
├─ Transfer_Multiples(pMshp_ID, pBenReq_ID)
│    ├─ SAS_Multiple.List_Values(pMshp_ID, 'TRA')
│    └─ [inserts Calcs_Transfer_Multiples]
├─ Multiples(pMshp_ID, pBenReq_ID, pExitDate)
│    ├─ SAS_Membership_Calcs.Get_Additional_Cover
│    └─ [inserts Calcs_Multiples]
│    [Note: CSSXfer/ExcessConts/Ongoing multiples hardcoded 0 — SAS_Multiple calls commented out]
├─ IRS_Cleanup(pMshp_ID, pBenReq_ID, pExitDate, pAggregate)
│    ├─ [cursor crIrregularService — types M/N ordered by start_date]
│    ├─ [cursor crNextPayday/crPrevPayday — Calcs_Paydays]
│    ├─ [cursor crCDDForIRS — Calcs_CDDs FOR UPDATE spanning IRS period]
│    ├─ [updates Calcs_CDDs — End_Date = prev payday]     (aggregate mode)
│    ├─ [inserts Calcs_CDDs — new record from next payday] (aggregate mode)
│    └─ [deletes Calcs_CDDs — CDDs within IRS range]       (non-aggregate mode)
├─ CDDs(pMshp_ID, pBenReq_ID, pExitDate, pAggregate default False)
│    ├─ [deletes Calcs_CDDs — clear existing]
│    ├─ SAS_Membership_Financials.Get_Birth_Date
│    ├─ SAS_Membership_Dues.Get_Dues (×2 — linked and current membership)
│    ├─ [cursor crLink — Links CONNECT BY, types 5/11 chain]
│    ├─ [cursor crDues/crSal1/crSal2 — Dues salary history]
│    ├─ [cursor crPayDates — Calcs_Paydays between start and exit]
│    ├─ [cursor crCeaseDate — Memberships]
│    ├─ SAS_Surcharge.Leap_Year (×4)
│    ├─ [inserts Calcs_CDDs]
│    ├─ [inserts/updates Calcs_Salaries]
│    └─ IRS_Cleanup (internal)
├─ Tax(pMshp_ID, pBenReq_ID)
│    ├─ SAS_Membership.Get_Join_Date (loop — chain traversal)
│    ├─ [cursor crPriorService — Prior_Services loop]
│    ├─ [cursor crOldPres — Old_Preservations loop]
│    ├─ [cursor crSTPIn — Stps, A_Serv_Comm]
│    ├─ [queries Links — types 3,4,5,11 chain traversal]
│    └─ [inserts Calcs_TaxData — TaxJoinDate]
├─ Reasonableness(pBenReq_ID, pScheme)
│    └─ Calcs_Reasonableness
├─ Surcharge(pApp_ID)
│    └─ [queries Ben_Surc_Data — Ben_App_ID = pApp_ID; sets gReturnCode]
└─ GetReturnCode() → number
     └─ [returns nvl(gReturnCode, 0)]
```

**Summary:** Data loading engine for the benefit calculation system. Reads membership, financial, and employment source data; resolves linked membership chains; and writes staged data into Calcs_* tables for consumption by the CALCS_LOAD2-11 calculation packages.
---

### CALCS_LOAD2 … CALCS_LOAD11

**Outbound calls:** No (CALCS_LOAD4–11); Yes (CALCS_LOAD2 — calls SAS_Item_Codes, SAS_Account, calcs_load4.*, calcs_load5.*, Calcs_Tax)

**Inbound callers:**
- CALCS_LOAD2: `AionDS` — batch system (Initialise, AddNextParamSet, Money_Items sequence)
- CALCS_LOAD4–11: called internally by CALCS_LOAD and AionDS batch system

**Note:** These ten packages form a modular calculation system split due to Oracle 7 compilation size limits. All share array types from `CALCS_STRIP` and global variables owned by `CALCS_LOAD5`. CALCS_LOAD3 does not exist — cluster jumps from 2 to 4.

**CALCS_LOAD2 — AionDS entry point and orchestrator (outbound_calls: Yes)**
```
CALCS_LOAD2
├─ Initialise(pMshpID, pBenReqID, pExitDate)
│    └─ ClearAllParameters (internal) → calcs_load4.ClearAllParameters
├─ AddNextParamSet(pDateType, pFromDate, pToDate, ...)   [overload 1 — full params]
│    └─ [sets calcs_load5 date period arrays: gFromDate, gToDate, gCalcIntFlag, etc.]
├─ AddNextParamSet(pDateType, pFromDate, pToDate)         [overload 2 — defaults all flags to 'Y']
│    └─ AddNextParamSet (internal, delegates to overload 1)
├─ Money_Items(pSGCFlag)                                  [main AionDS entry point]
│    ├─ SetUpItemCodes (internal) → SAS_Item_Codes.* (×9 item code functions)
│    ├─ calcs_load4.InitialiseArrays
│    ├─ SAS_Account.Scheme
│    ├─ calcs_load5.CalculateItems (current membership)
│    ├─ [queries Links — CONNECT BY link types 5/11 CSS transfer chain]
│    ├─ calcs_load5.CalculateItems (loop — each linked predecessor)
│    ├─ calcs_load4.InsertItemsIntoTable
│    └─ RecordError (internal, on exception) → [inserts Calcs_Errors]
├─ Calculate_ICD2(pProcessingLink, pDatePtr, pID, pIntRateCode, ...)
│    ├─ calcs_load4.FindAmountAndInterestICD2 (×3 per page type)
│    └─ Calcs_Tax.Calc_tax (conditional: MPSTI/MPF page types with tax rate)
├─ SetStartAndEndDates (internal)
│    └─ [queries Calcs_Tmp_Items — min/max effective_date by Seq_No]
└─ SetCalcDates (internal)
     └─ [loops calcs_load5 arrays; sets gCalcFromDate, gCalcToDate, gBalanceNeeded]
```

**Package responsibilities across the cluster:**

| Package | Primary Responsibility |
|---|---|
| `CALCS_LOAD2` | AionDS entry point; orchestrates Money_Items calculation; ICD2 projection |
| `CALCS_LOAD4` | Item summation, interest rate codes, interest calculations; owns InsertItemsIntoTable |
| `CALCS_LOAD5` | Owns all cluster shared globals (60+); `CalculateItems` — core engine iterating Money_Page_Types × date periods; handles paid/due/SGC/productivity per dataset type |
| `CALCS_LOAD6` | Array position finding for date range matching |
| `CALCS_LOAD7` | Item setup and calculation date processing |
| `CALCS_LOAD8` | Item summation — paid/due/tax/interest accumulation |
| `CALCS_LOAD9` | Complex item calculations with balance and interest handling |
| `CALCS_LOAD10` | Transfer values and transfer interest accumulation |
| `CALCS_LOAD11` | Preservation status checking and partial claim processing |

All packages query `Calcs_Tmp_Items`, `Money_Page_Types`, `Schemes`, and various financial history tables.
## Group 4 — External System Interfaces

---

### SAS_UNIX_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected (called directly by external Unix processes via DBMS_PIPE)

**Outbound call tree:**
```
SAS_UNIX_INTERFACE
├─ Close_Pipes()
│    └─ DBMS_PIPE.remove_pipe()
└─ Call_Unix(pOperation, pResultCode, pReturnString, pInPipe, pOutPipe)
     ├─ [queries BCS_PIPE_IDS sequence]
     ├─ DBMS_PIPE.create_pipe()
     ├─ DBMS_PIPE.pack_message()
     ├─ DBMS_PIPE.send_message()
     ├─ DBMS_PIPE.receive_message()
     ├─ DBMS_PIPE.unpack_message()
     └─ DBMS_PIPE.purge()
```

**Summary:** Low-level UNIX communication interface using Oracle DBMS_PIPE for synchronous inter-process communication with external dispatcher processes.

---

### SAS_BCS_INTERFACE

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_BCS_INTERFACE2` — Send_To_BCS, Translate_Error_Code
- `SAS_BCS_INTERFACE3` — Initialise, Send_To_BCS, Translate_Error_Code, Tokenize_String
- `SAS_BCS_INTERFACE4` — Check_Operation references gvExtraErrorInformation

**Outbound call tree:**
```
SAS_BCS_INTERFACE
├─ Initialise()
│    ├─ [queries SAS_GLOBALS table]
│    └─ DBMS_PIPE.create_pipe()
├─ Tokenize_String(pString, pTable)
│    └─ [parses delimited string into array]
├─ Do_Operation_Return()
│    ├─ Tokenize_String (internal)
│    └─ SAS_BCS_INTERFACE3.Do_OperationPension()
├─ Do_Operation()
│    └─ SAS_BCS_INTERFACE3.Do_OperationPension()
├─ Send_To_BCS(pOperation, pParameterString, pResultCode, pReturnString)
│    ├─ Initialise (internal)
│    ├─ SAS_BCS_INTERFACE4.Check_Operation()
│    ├─ [queries BCS_PIPE_IDS sequence]
│    ├─ DBMS_PIPE operations (create, pack, send, receive, unpack, purge)
│    └─ Do_Operation_Return (internal)
└─ Translate_Error_Code()
     └─ [maps BCS result codes to error messages]
```

**Summary:** Main BCS (mainframe) interface package managing LU6.2 pipe communications, operation validation, and result processing for pension/benefit transactions.

---

### SAS_BCS_INTERFACE2

**Outbound calls:** Yes

**Inbound callers:**
- None detected (called from benefit application workflow)

**Outbound call tree:**
```
SAS_BCS_INTERFACE2
└─ SendPensionApplication(pBenApplID, pResultCode)
     ├─ [queries Pension_Requests, Ben_Applications, Benefit_Requests]
     ├─ SAS_WORKFLOW_APPLIN.Get_Application_From_Mshp_ID() (×2)
     ├─ SAS_WORKFLOW.Task_Dates()
     ├─ SAS_INTERNET3.Get_Membership_From_ID()
     ├─ SAS_INTERNET.GetError()
     ├─ SAS_QLFN.Get_Qlfn()
     ├─ EXT_VALIDATION.Check_BSB()
     ├─ SAS_BCS_INTERFACE3.Get_Bank_Initials()
     ├─ ConcatString() (×37 — builds parameter string)
     ├─ SAS_BCS_INTERFACE.Send_To_BCS()
     └─ SAS_BCS_INTERFACE.Translate_Error_Code()
```

**Summary:** Composes and sends pension application data to BCS by gathering member, benefit, and tax details into a parameter string.

---

### SAS_BCS_INTERFACE3

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_BCS_INTERFACE` — Do_OperationPension callback

**Outbound call tree:**
```
SAS_BCS_INTERFACE3
├─ Get_Bank_Initials(pPayee, pSurname) → varchar2
│    └─ [string manipulation to derive bank initials]
├─ SendApprovePension(pBenApplID, pResultCode)
│    ├─ [queries Pension_Requests, Ben_Applications, Benefit_Requests]
│    ├─ SAS_WORKFLOW_APPLIN.Get_Application_From_Mshp_ID()
│    ├─ SAS_INTERNET3.Get_Membership_From_ID()
│    ├─ SAS_BCS_INTERFACE2.ConcatString() (multiple)
│    ├─ SAS_BCS_INTERFACE.Send_To_BCS()
│    └─ SAS_BCS_INTERFACE.Translate_Error_Code()
├─ Update_Pension_Details()
│    ├─ [queries Tax_Declarations, Pension_Requests, People]
│    ├─ [updates Tax_Declarations, People, Pension_Requests]
│    ├─ EXT_VALIDATION.Check_BSB()
│    └─ SAS_AMENDMENTS.SAS_Amendments() (×8)
└─ Do_OperationPension(pParameterString, pResultCode, pReturnString)
     ├─ SAS_BCS_INTERFACE.Tokenize_String()
     ├─ SAS_INTERNET3.Get_Membership()
     ├─ SAS_INTERNET.GetError()
     ├─ SAS_WORKFLOW_APPLIN.Get_Application_From_Mshp_ID()
     ├─ [queries People, Addresses]
     ├─ [inserts into PENS_DUE, PENS_PAID, JOURNAL_ENTRY, BCS_PENSION_VARS]
     ├─ SAS_WORKFLOW.Complete_Task()
     └─ Update_Pension_Details (internal)
```

**Summary:** Handles pension approval processing and detailed return data from BCS, inserting pension calculations and managing workflow task completion.

---

### SAS_BCS_INTERFACE4

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_BCS_INTERFACE` — Check_Operation callback

**Outbound call tree:**
```
SAS_BCS_INTERFACE4
├─ Check_Operation(pOperation, pParameterString) → NUMBER
│    ├─ SAS_BCS_INTERFACE.Tokenize_String()
│    └─ [queries Memberships, Benefit_Requests]
└─ Poll_Mainframe()
     ├─ [queries WP_Applin_1 cursor (WAITBCS status)]
     ├─ MakeParameterString (nested procedure)
     │    └─ SAS_BCS_INTERFACE2.ConcatString()
     ├─ RemoveAGS (nested procedure)
     ├─ RemoveAllParameters (nested procedure)
     │    └─ SAS_BATCH.Error() (on AGS not found)
     ├─ SAS_BCS_INTERFACE.Send_To_BCS()
     ├─ SAS_BCS_INTERFACE.Translate_Error_Code()
     ├─ SAS_BATCH.Error() (on comms error)
     ├─ commit
     └─ rollback
```

**Summary:** Validates BCS operation parameters and polls the mainframe for pending pension applications using AGS number batching.

---

### SAS_INTERNET … SAS_INTERNET6

**Outbound calls:** Yes

These six packages form an interdependent ETL cluster bridging CBA/INET schemas into ComSAS.

**Outbound calls:** Yes

**Inbound callers:**
- None detected at the cluster boundary (called from benefit application layer)

**Outbound call tree:**
```
SAS_INTERNET  [orchestrator]
└─ Populate_INET_ComSAS_Tables(pCBAApplID, pOK, pMembershipID, pINETApplID)
     ├─ SAS_INTERNET5.Get_CBA_Application()
     ├─ SAS_INTERNET3.Get_Membership_From_ID()
     ├─ SAS_INTERNET5.Check_CBA_Application_Mshp()
     ├─ SAS_INTERNET5.Get_User_Details()
     ├─ SAS_INTERNET5.Insert_INET_Personnel_Officer()
     ├─ [queries Ben_Applications, Benefit_Requests]
     ├─ SAS_INTERNET5.Insert_INET_Application()
     ├─ SAS_INTERNET6.Insert_INET_Applicant()
     ├─ SAS_INTERNET6.CopyCBAPeople()
     ├─ SAS_INTERNET6.Insert_INET_pension()
     └─ SAS_INTERNET6.CopyCBARolloverRequests()

SAS_INTERNET2  [INET → ComSAS transfer]
└─ Populate_ComSAS_Tables(pINETApplID, pOK, pBenApplID)
     ├─ SAS_INTERNET3.Get_INET_Application()
     ├─ SAS_INTERNET3.Get_Membership()
     ├─ SAS_INTERNET3.Check_Application_Membership()
     ├─ SAS_INTERNET3.Get_Applicant()
     ├─ SAS_INTERNET3.Get_Or_Create_Applicant_ID()
     ├─ SAS_INTERNET3.Check_Person()
     ├─ SAS_INTERNET3.Insert_application()
     ├─ SAS_INTERNET3.CopyAddresses / CopyPhones / CopyEmails / CopyPeople
     ├─ SAS_INTERNET4.CopyBenefitRequests()
     ├─ SAS_INTERNET6.Insert_Rollover_Requests()
     └─ SAS_INTERNET6.Insert_Benefit_Request()

SAS_INTERNET3  [data retrieval / person/application operations]
     ├─ Get_INET_Application / Get_Membership / Get_Membership_From_ID
     ├─ Get_Applicant / Get_Or_Create_Applicant_ID / Check_Person
     ├─ Insert_application / CopyAddresses / CopyPhones / CopyEmails / CopyPeople
     └─ SAS_INTERNET4.Get_Membership_From_ID (delegated)

SAS_INTERNET4  [tax/personnel officer/benefit request copy]
     ├─ CopyTaxDeclaration()    → INET_TAX_DECLARATIONS → TAX_DECLARATIONS
     ├─ CopyPersonnelOfficer()  → INET_Personnel_Officers → Personnel_Officers
     ├─ Get_Membership_From_ID()
     └─ CopyBenefitRequests()

SAS_INTERNET5  [CBA extraction]
     ├─ Get_CBA_Application()           → CBA_APPLICATIONS
     ├─ Check_CBA_Application_Mshp()
     │    └─ SAS_INTERNET.Check_Mshp_ID / Check_Exit_Type_Option / Check_Exit_Salary
     ├─ Get_User_Details()              → User_Details
     ├─ Insert_INET_Personnel_Officer() → INET_Personnel_Officers
     └─ Insert_INET_Application()       → INET_APPLICATIONS

SAS_INTERNET6  [CBA person/pension/rollover conversion]
     ├─ ConvertCBARelationshipToINET()  → relationship code mapping
     ├─ Insert_INET_Applicant()         → CBA_People → INET_PEOPLE / INET_ADDRESSES
     ├─ Insert_INET_pension()           → CBA_PENSION_REQUESTS → INET_PENSION_REQUESTS
     ├─ CopyCBAPeople()
     ├─ CopyCBARolloverRequests()
     └─ Insert_Benefit_Request()        → Ben_Applications insert
```

**Summary:** Six-package ETL cluster transferring benefit application data between CBA, INET, and ComSAS schemas. Package 1 is the orchestrator for CBA→INET; package 2 handles INET→ComSAS; packages 3-6 supply domain-specific retrieval, copy, and conversion procedures.

---

### SAS_STLT_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected (called from standard letter generation jobs)

**Outbound call tree:**
```
SAS_STLT_INTERFACE
├─ Insert_Data()
│    └─ [inserts Stlt_Data_Strings]
└─ Create_Member_Record()
     ├─ [queries Memberships, People, Item1, Addresses]
     └─ Insert_Data (internal, multiple)
```

**Summary:** Gathers civilian new grant settlement data for standard letter template merge, inserting formatted records into Stlt_Data_Strings.

---

### SAS_CONT_STLT_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected

**Outbound call tree:**
```
SAS_CONT_STLT_INTERFACE
├─ Insert_Data()
│    └─ [inserts Stlt_Data_Strings]
└─ Get_Cont_Ltr_Data()
     ├─ [queries Employment_Record, Memberships, Agencies, Pay_Centres, Addresses]
     └─ Insert_Data (internal, multiple)
```

**Summary:** Collects contribution and employment data for contributions/unclaimed-contribution standard letters.

---

### SAS_MAN_STLT_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected

**Outbound call tree:**
```
SAS_MAN_STLT_INTERFACE
├─ Insert_Data()
│    └─ [inserts Stlt_Data_Strings]
└─ Get_Man_Application_Ltr_Data()
     ├─ [queries ManBP_App_Details, Memberships, People, Addresses, payment data]
     └─ Insert_Data (internal, multiple)
```

**Summary:** Prepares manual benefit payment application data for approval officer workbench and benefit estimate standard letters.

---

### SAS_ADDIC_STLT_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected

**Outbound call tree:**
```
SAS_ADDIC_STLT_INTERFACE
├─ Insert_Data()
│    └─ [inserts Stlt_Data_Strings]
└─ Get_Addic_Letter_Data() [overloaded]
     ├─ [queries Additional_Covers and related benefit tables]
     └─ Insert_Data (internal, multiple)
```

**Summary:** Gathers additional covers (insurance) benefit estimate data for standard letter generation.

---

### SAS_PRESUA_STLT_INTERFACE / SAS_PRESUM_STLT_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected

**Outbound call tree:**
```
SAS_PRESUA_STLT_INTERFACE / SAS_PRESUM_STLT_INTERFACE
├─ Insert_Data()
│    └─ [inserts Stlt_Data_Strings]
└─ BATCH_GENERATE()
     ├─ [queries Letter_Params, Letters]
     └─ [inserts Batched_Letters, Batched_Letter_Params]
```

**Summary:** Automatic batch generation of preserved unclaimed member letters (two variants — UA and UniversalAustralia — for different preserved member categories).

---

### SAS_STLT_EST_INTERFACE

**Outbound calls:** No

**Inbound callers:**
- None detected

**Outbound call tree:**
```
SAS_STLT_EST_INTERFACE
├─ SAS_Approved_Authority() → boolean
│    └─ [queries Sponsorship_Qlfns]
├─ Insert_Data()
│    └─ [inserts Stlt_Data_Strings]
└─ Get_Estimate_Letter_Data()
     ├─ [queries Ben_Applications and benefit calculation tables]
     ├─ SAS_Approved_Authority (internal)
     └─ Insert_Data (internal, multiple)
```

**Summary:** Compiles benefit estimate data for standard letters with approved authority status validation.

---

### DM_SEND_STOP_PIPE

**Outbound calls:** No

**Inbound callers:**
- None detected (called from migration control scripts)

**Outbound call tree:**
```
DM_SEND_STOP_PIPE
└─ Send_Stop_Pipe()
     ├─ DBMS_PIPE.PACK_MESSAGE('STOP')
     ├─ DBMS_PIPE.SEND_MESSAGE('dmmessage')
     ├─ DBMS_PIPE.PURGE('dmmessage')
     └─ DBMS_PIPE.RESET_BUFFER()
```

**Summary:** Simple utility sending a STOP signal via DBMS_PIPE to the 'dmmessage' pipe to halt external migration processes.

---

## Group 5 — Data Migration / ETL Loaders

All DM_LOAD_* packages share these conventions:
- Communicate progress via `DBMS_PIPE` on the `dmmessage` pipe
- Use `SAVEPOINT` / `ROLLBACK TO SAVEPOINT` per row for partial-failure recovery
- Periodic `COMMIT` every N rows to manage transaction size
- No inbound callers detected — all are external entry points

Two structural patterns exist across the 24 loader packages:

**Pattern A — Simple Row-by-Row:** cursor loop directly over temp table, no batch control  
**Pattern B — Batch-Controlled:** driven by `DM_Batch_Headers_Temp` (Sq_No) with audit logging to `DM_Audit_Seq_Log`

---

### DM_LOAD_PEOPLE  *(Pattern A)*

**Outbound calls:** No

```
People_Load
├─ Cursor crPeople on DM_People_Temp
├─ Comments_Seq.Nextval / Currval
├─ INSERT Comments / People / Person_Hist
└─ COMMIT (every 50,000 rows)
```
Source: `DM_People_Temp` → Target: `People`, `Person_Hist`, `Comments`

---

### DM_LOAD_EMPLOYMENT  *(Pattern A)*

**Outbound calls:** No

```
Employment_Record_Load
├─ Cursor on DM_Employment_Temp
├─ SELECT ID from Agencies (by External_ID)   [cached: vPrevAgncy]
├─ SELECT ID from Sponsorships (Agncy_ID, Sch_ID)
├─ Comments_Seq.Nextval / Currval
├─ INSERT Comments / Employment_Record / Employment_Record_Hist
└─ COMMIT (every 5,000 rows)
```
Source: `DM_Employment_Temp` → Target: `Employment_Record`, `Employment_Record_Hist`, `Comments`

---

### DM_LOAD_PAYMENTS  *(Pattern B, Sq_No = 3)*

**Outbound calls:** No

```
Set_Up_Payments
├─ Set_Up_Header          → SELECT DM_Batch_Headers_Temp (Sq_No=3)
├─ Set_Up_Audit_Logs      → INSERT/UPDATE DM_Audit_Seq_Log
├─ Process_Payments
│    ├─ Cursor on DM_Payments_Temp
│    └─ INSERT Payments / Lump_Sum_Log
└─ Update_Audit_Logs      → UPDATE DM_Audit_Log, DM_Audit_Seq_Log
```
Source: `DM_Payments_Temp` → Target: `Payments`, `Lump_Sum_Log`, `DM_Batch_Log`

---

### DM_LOAD_BEN_APPLICATIONS  *(Pattern B, Sq_No = 1)*

**Outbound calls:** No

```
Set_Up_Ben_Applications
├─ Set_Up_Header          → SELECT DM_Batch_Headers_Temp (Sq_No=1)
├─ Set_Up_Audit_Logs      → INSERT/UPDATE DM_Audit_Seq_Log
├─ Process_Ben_Applications
│    ├─ Cursor on DM_Benefit_Applications_Temp
│    └─ INSERT Ben_Applications
└─ Update_Audit_Logs
```
Source: `DM_Benefit_Applications_Temp` → Target: `Ben_Applications`, `DM_Batch_Log`, `DM_LumpSum_Log`

---

### DM_LOAD_BENEFIT_REQUESTS  *(Pattern B, Sq_No = 2)*

**Outbound calls:** No

```
Set_Up_Benefit_Requests
├─ Set_Up_Header (Sq_No=2) / Set_Up_Audit_Logs
└─ Process_Benefit_Requests
     └─ Cursor on DM_Benefit_Requests_Temp → INSERT Benefit_Requests
```
Source: `DM_Benefit_Requests_Temp` → Target: `Benefit_Requests`, `DM_Batch_Log`

---

### DM_LOAD_CASH_PAYMENTS  *(Pattern B, Sq_No = 9)*

**Outbound calls:** No

```
Set_Up_Cash_Payments
├─ Set_Up_Header (Sq_No=9) / Set_Up_Audit_Logs
└─ Process_Cash_Payments
     └─ Cursor on DM_Cash_Payments_Temp → INSERT Cash_Payments
```
Source: `DM_Cash_Payments_Temp` → Target: `Cash_Payments`, `DM_Batch_Log`

---

### DM_LOAD_PAYMENT_ITEMS  *(Pattern B, Sq_No = 4)*

**Outbound calls:** No

```
Set_Up_Payment_Items
├─ Set_Up_Header (Sq_No=4) / Set_Up_Audit_Logs
└─ Process_Payment_Items
     └─ Cursor on DM_Payment_Items_Temp → INSERT Payment_Items
```
Source: `DM_Payment_Items_Temp` → Target: `Payment_Items`, `DM_Batch_Log`

---

### DM_LOAD_ROLLOVER_PAYMENTS  *(Pattern B, Sq_No = 8)*

**Outbound calls:** No

```
Set_Up_Rollover_Payments
├─ Set_Up_Header (Sq_No=8) / Set_Up_Audit_Logs
└─ Process_Rollover_Payments
     └─ Cursor on DM_Rollover_Payments_Temp → INSERT Rollover_Payments
```
Source: `DM_Rollover_Payments_Temp` → Target: `Rollover_Payments`, `DM_Batch_Log`

---

### DM_LOAD_STP_PAYMENTS  *(Pattern B, Sq_No = 7)*

**Outbound calls:** No

```
Set_Up_STP_Payments
├─ Set_Up_Header (Sq_No=7) / Set_Up_Audit_Logs
└─ Process_STP_Payments
     └─ Cursor on DM_STP_Payments_Temp → INSERT STP_Payments
```
Source: `DM_STP_Payments_Temp` → Target: `STP_Payments`, `DM_Batch_Log`

---

### DM_LOAD_TAX_BREAKUPS  *(Pattern B, Sq_No = 5)*

**Outbound calls:** No

```
Set_Up_Tax_Breakups
├─ Set_Up_Header (Sq_No=5) / Set_Up_Audit_Logs
└─ Process_Tax_Breakups
     └─ Cursor on DM_Tax_Breakups_Temp → INSERT Tax_Breakups
```
Source: `DM_Tax_Breakups_Temp` → Target: `Tax_Breakups`, `DM_Batch_Log`

---

### DM_LOAD_TAX_COMPONENTS  *(Pattern B, Sq_No = 6)*

**Outbound calls:** No

```
Set_Up_Tax_Components
├─ Set_Up_Header (Sq_No=6) / Set_Up_Audit_Logs
└─ Process_Tax_Components
     └─ Cursor on DM_Tax_Components_Temp → INSERT Tax_Components
```
Source: `DM_Tax_Components_Temp` → Target: `Tax_Components`, `DM_Batch_Log`

---

### DM_LOAD_TAX_PAYMENTS  *(Pattern B, Sq_No = 10)*

**Outbound calls:** No

```
Set_Up_Tax_Payments
├─ Set_Up_Header (Sq_No=10) / Set_Up_Audit_Logs
└─ Process_Tax_Payments
     └─ Cursor on DM_Tax_Payments_Temp → INSERT Tax_Payments
```
Source: `DM_Tax_Payments_Temp` → Target: `Tax_Payments`, `DM_Batch_Log`

---

### DM_LOAD_COURT_ORDERS  *(Pattern A)*

**Outbound calls:** No

```
Court_Order
├─ Cursor on DM_Court_Orders_Temp
├─ Comments_Seq.Nextval / Currval
├─ INSERT Court_Orders / Comments
└─ COMMIT (every 50 rows)
```
Source: `DM_Court_Orders_Temp` → Target: `Court_Orders`, `Comments`

---

### DM_LOAD_CSTM_COMMENTS  *(Pattern A)*

**Outbound calls:** No

```
Cstm_comments
├─ Cursor on DM_Cstm_Temp
├─ Qualification_Seq.Nextval / Currval
├─ INSERT Membership_Qlfns (MANUALLY_PAID_BENEFIT='Y') / Membership_Qlfn_Hist
├─ UPDATE Memberships (set Comments_key)
├─ Comments_Seq.Nextval / Currval
└─ INSERT Comments
```
Source: `DM_Cstm_Temp` → Target: `Membership_Qlfns`, `Membership_Qlfn_Hist`, `Memberships`, `Comments`

---

### DM_LOAD_LINK_MONIES  *(Pattern A)*

**Outbound calls:** No

```
Link_Monies_Load
├─ Cursor on DM_Link_Mony_Temp
├─ SELECT ID from Links (by From_Account_ID, To_Account_ID)
├─ INSERT Link_Monies
└─ COMMIT (every 1,000 rows)
```
Source: `DM_Link_Mony_Temp` → Target: `Link_Monies`

---

### DM_LOAD_MEDICALS  *(Pattern A, complex)*

**Outbound calls:** No

```
Unload_DM_Medicals_Temp
├─ Cursor on DM_Medicals_Temp
├─ SELECT from Mshp_Med_Dtrms (by External_ID)
│    └─ no_data_found → INSERT Mshp_Med_Dtrms (Mmdtrm_Seq.Nextval)
├─ INSERT Medical_Conditions  (MedCond_Seq.Nextval)
├─ INSERT Medical_Decisions   (MedDcsn_Seq.Nextval)
├─ INSERT Process_Decisions   (Prc_Dcsn_Seq.Nextval)
└─ INSERT Work_Status
```
Source: `DM_Medicals_Temp` → Target: `Mshp_Med_Dtrms`, `Medical_Conditions`, `Medical_Decisions`, `Process_Decisions`, `Work_Status`

---

### DM_LOAD_MEMBERSHIP_QLFNS  *(Pattern A)*

**Outbound calls:** No

```
Membership_Qlfns_Load
├─ Cursor on DM_Mship_Qlfns_Temp
├─ INSERT Membership_Qlfns / Membership_Qlfn_Hist
└─ COMMIT (every 1,000 rows)
```
Source: `DM_Mship_Qlfns_Temp` → Target: `Membership_Qlfns`, `Membership_Qlfn_Hist`

---

### DM_LOAD_ADDITIONAL_COVER  *(Pattern A, two procedures)*

**Outbound calls:** No

```
Additional_Cover_Rates
├─ SELECT ID from Organisations (National Mutual) / Schemes (PSS)
├─ Cursor on DM_Cover_Rates_Temp
├─ Cvrttab_Seq.Nextval
└─ INSERT Cover_Rates / Cover_Rate_Hist

Additional_Cover
├─ Cursor on DM_Add_Cover_Temp
├─ SELECT Cover_Rates (by type)
└─ INSERT Additional_Covers / Additional_Cover_Hist
```
Source: `DM_Cover_Rates_Temp`, `DM_Add_Cover_Temp` → Target: `Cover_Rates`, `Cover_Rate_Hist`, `Additional_Covers`, `Additional_Cover_Hist`

---

### DM_LOAD_EMPLOYER_MANAGEMENT  *(Pattern A, multi-table orchestrator)*

**Outbound calls:** No

```
Unload_Employer_Temp_Tables
├─ INSERT Organisations (hardcoded: National Mutual, Pre ComSAS Org)
├─ INSERT Organisation_Hist
├─ Cursor on DM_Old_Agencies_Temp
│    ├─ INSERT Agencies / Agency_Hist
│    ├─ UPDATE DM_Contacts_Temp (Org_Unit_ID)
│    ├─ UPDATE DM_Addresses_Temp (Org_Unit_ID)
│    └─ UPDATE DM_Phones_Temp (Org_Unit_ID)
└─ [must run BEFORE Unload_Contacts_Temp_Tables]
```
Source: `DM_Old_Agencies_Temp` → Target: `Organisations`, `Organisation_Hist`, `Agencies`, `Agency_Hist`; also updates downstream temp tables.

---

### DM_LOAD_NEW_AGENCIES  *(Pattern A, complex multi-table)*

**Outbound calls:** No

```
Load_New_Agencies
├─ Cursor on DM_New_Organisations_Temp
│    ├─ Org_Unit_Seq.Nextval
│    ├─ INSERT Organisations / Organisation_Hist
│    └─ Cursor on DM_New_Agencies_Temp (nested, by Org_ID)
│         ├─ UPDATE or INSERT Agencies / Agency_Hist
│         ├─ Org_Unit_Seq / Contact_Seq.Nextval
│         ├─ INSERT Contacts / Contact_Groups
│         └─ INSERT Addresses / Phones
└─ DBMS_PIPE messages
```
Source: `DM_New_Organisations_Temp`, `DM_New_Agencies_Temp` → Target: `Organisations`, `Agencies`, `Contacts`, `Contact_Groups`, `Addresses`, `Phones`

---

### DM_LOAD_NEW_EMP_INFO  *(Pattern A, multi-procedure)*

**Outbound calls:** No

```
Load_New_Emp_Info
├─ Cursor on DM_New_Emp_Info_Temp
├─ Conditional on Contact_Type (S/F/B/A)
│    ├─ Get_Agency_Contact_ID (internal)
│    ├─ Contact_Seq.Nextval
│    ├─ INSERT Contacts
│    ├─ Insert_Contact_Group (internal)
│    └─ Insert_Addresses_and_Phones (internal)
├─ SELECT from Agencies (by External_ID)
├─ INSERT Contact_Groups / Addresses / Phones
```
Source: `DM_New_Emp_Info_Temp` → Target: `Pay_Centres`, `Contacts`, `Contact_Groups`, `Addresses`, `Phones`

---

### DM_LOAD_PROD_QLFNS  *(Pattern A)*

**Outbound calls:** No

```
Load_Prod_Qlfns
├─ Cursor on DM_Prod_Qlfns_Temp
├─ SELECT ID from Agencies (by External_ID)
├─ SELECT ID from Sponsorships (Agncy_ID, CSS scheme)
├─ Conditional INSERT Sponsorship_Qlfns:
│    ├─ If Productivity_Eligible='A' → INSERT SPONSOR_PAYS_PRODUCTIVITY
│    └─ If GBE_Min_Prod > 0         → INSERT GBE_PRODUCTIVITY_MIN
├─ INSERT Sponsorship_Qlfn_Hist
└─ [handles redirected agencies recursively]
```
Source: `DM_Prod_Qlfns_Temp` → Target: `Sponsorship_Qlfns`, `Sponsorship_Qlfn_Hist`

---

### DM_LOAD_REDIRECT_AGENCY_TO  *(Pattern A)*

**Outbound calls:** No

```
Redirect_Agency_To
├─ Cursor on DM_Agency_Redirect_Temp
├─ SELECT ID from Agencies (by External_ID)
└─ UPDATE Agencies set Redirected_To = vAgenciesID
```
Source: `DM_Agency_Redirect_Temp` → Target: `Agencies` (update only)

---

### DM_LOAD_TMP_BENEFITS  *(complex, two paths)*

**Outbound calls:** No

```
Set_Up_Tmp_Benefits
├─ Cursor on DM_LumpSum_Log (PYMTL status)
│    ├─ If BenReq_ID in 70000..150001:
│    │    └─ Load_From_Migrated_File
│    │         ├─ Cursor on DM_Tmp_Benefits_Temp
│    │         └─ INSERT Tmp_Benefits
│    └─ Else:
│         └─ Load_From_Comsas(Pymt_ID)
├─ Tmp_Benefit_Seq.Nextval
├─ UPDATE DM_LumpSum_Log
└─ COMMIT (every 500 rows)
```
Source: `DM_LumpSum_Log`, `DM_Tmp_Benefits_Temp` → Target: `Tmp_Benefits`, `DM_LumpSum_Log`

---

### DM_SCAN_BATCH_LOG  *(post-processing orchestrator)*

**Outbound calls:** No

```
Batch_To_LumpSum_Log
├─ Scan_DM_Batch_Log (internal)
│    ├─ Cursor on DM_Batch_Log (Rec_Complete IS NULL)
│    ├─ Checks SqFile_1 … SqFile_10 columns
│    └─ UPDATE DM_Batch_Log set Rec_Complete='R' when all sequences complete
└─ Update_DM_LumpSum_Log (internal)
     ├─ Cursor on DM_Batch_Log (Rec_Complete='R')
     └─ UPDATE DM_LumpSum_Log (Process_Status='PYMTLD')
```
Source: `DM_Batch_Log`, `DM_LumpSum_Log` → Target: `DM_Batch_Log`, `DM_LumpSum_Log` (updates only)

**Summary:** Post-processing orchestrator that checks all ten batch sequence files are complete before marking records as ready for financial posting.

---

## Group 6 — Workflow Orchestrators

---

### SAS_WORKFLOW

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_WORKFLOW_APPLIN` — Cease_Pending, Complete_Job
- `SAS_WORKFLOW_NBPO` — Start_Task, Complete_Task, Start_Pending
- `SAS_BCS_INTERFACE3` — Complete_Task
- `SAS_WORKFLOW_MANBP2` — Start_Pending

**Outbound call tree:**
```
SAS_WORKFLOW
├─ Create_Work_Packet(pJobType, pCreatedDate, pPriority, pReferenceID, pProcessMethod)
│    ├─ [queries WORKFLOWS, WORKFLOW_ITEMS]
│    ├─ [sequences WORK_PACKETS_ID, TASKS_ID]
│    └─ Create_Task (internal, recursive)
├─ Create_Task(pWPID, pWorkflowItem, pProcessMethod, pCreatedDate, pCheckDoItem)
│    ├─ Check_Do_Item (internal — dynamic call via Workflow_Items.FN_Check_Do_Item)
│    └─ Complete_Job (when task chain completes)
├─ Set_Item_Properties(pWPID, pTaskID)
│    ├─ DYN_PROCEDURE.Open_And_Parse
│    ├─ DYN_PROCEDURE.Execute_Cursor
│    └─ DYN_PROCEDURE.Close_Cursor
├─ Start_Task(pWPID, pUserID, pStartDate)
│    ├─ Set_Item_Properties (internal)
│    └─ [updates TASKS]
├─ Complete_Task(pWPID, pCompletionStatus, pEndDate)
│    ├─ Complete_Job (when all tasks done)
│    └─ Create_Task (for next workflow item)
├─ Complete_Job(pWPID)
│    ├─ DYN_PROCEDURE.Open_And_Parse (dynamic FN_Complete call)
│    ├─ DYN_PROCEDURE.Execute_Cursor
│    └─ [queries WORKFLOWS, WORK_PACKETS; deletes uncompleted TASKS]
├─ Delete_WP / Reenter_WP / Cancel_WP
│    └─ DYN_PROCEDURE (dynamic FN_Delete / FN_Reenter / FN_Cancel)
├─ Start_Pending(pWPID, pPendedDate, pExpectedDaysPending, pPendingTypeName, pReason)
│    ├─ [inserts PENDING_TASKS]
│    └─ [queries CODE_VALUES]
├─ Cease_Pending(pWPID)
│    └─ [updates TASKS, PENDING_TASKS]
├─ Task_Dates(pWPID, pWFItemName) → dates
│    └─ [queries TASKS]
└─ Change_Task_Processing(pWPID, pWFTaskName, pAutomateFlag)
     └─ [updates TASKS, queries WORKFLOW_ITEMS]
```

**Summary:** Core workflow engine managing work packet lifecycle (creation, task sequencing, suspension, completion) with dynamic invocation of workflow-specific handlers stored in Workflow_Items function references.

---

### SAS_WORKFLOW_APPLIN

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_WORKFLOW_APPLIN_APPROVAL` — Reject_Approve
- `SAS_WORKFLOW_APPLIN_AUTHORISE` — Reject_Authorise
- `SAS_WORKFLOW_APPLIN_RECONCILE` — Reject_RECONCILE
- Called from application layer (direct)

**Outbound call tree:**
```
SAS_WORKFLOW_APPLIN
├─ Get_Application(pWorkPacketID)
│    └─ [queries WORK_PACKETS, WORKFLOWS, BEN_APPLICATIONS]
├─ Get_Application_From_Appl_ID(pApplID)
│    └─ Get_Application (internal)
├─ Get_Latest_Task / Get_Previous_Task(pWorkPacketID, pTaskName)
│    └─ [queries TASKS ordered by ID desc / Start_Date desc]
├─ Delete_Workpacket(pWorkPacketID, pDeleteCBA)
│    ├─ Get_Application (internal)
│    ├─ SAS_WORKFLOW_APPLIN_APPROVAL.Reject_Approve
│    ├─ SAS_WORKFLOW_APPLIN_AUTHORISE.Reject_Authorise
│    ├─ SAS_WORKFLOW_APPLIN_RECONCILE.Reject_RECONCILE
│    ├─ Calcs_Rollback (per benefit request)
│    ├─ SAS_WORKFLOW.Cease_Pending
│    └─ SAS_CBA_DELETE_APPLICATION.DeleteApplication
├─ Complete_Workpacket(pWorkPacketID)
│    ├─ Get_Application (internal)
│    ├─ SAS_MEMBERSHIP_EXIT.Calc_Status_Confirmed
│    ├─ SAS_RBL_INFORMATION.InsertRBLInformation
│    └─ SAS_CBA_DELETE_APPLICATION.DeleteApplication
├─ Reenter_Workpacket(pWorkPacketID)
│    ├─ SAS_WORKFLOW_APPLIN_APPROVAL.Reject_Approve
│    ├─ SAS_WORKFLOW_APPLIN_AUTHORISE.Reject_Authorise
│    ├─ SAS_WORKFLOW_APPLIN_RECONCILE.Reject_RECONCILE
│    └─ SAS_MEMBERSHIP_EXIT.Calc_Status_Rejected
└─ Cancel_Workpacket(pWorkPacketID)
     ├─ [updates BEN_APPLICATIONS, CBA_APPLICATIONS, TASKS, WORK_PACKETS]
     └─ SAS_MEMBERSHIP_EXIT.Calc_Status_Rejected
```

**Summary:** APPLIN workflow orchestrator handling application lifecycle events (deletion, completion, re-entry, cancellation) with transitions to approval/authorisation/reconciliation sub-workflows.

---

### SAS_WORKFLOW_APPLIN_ACTION

**Outbound calls:** Yes

**Inbound callers:**
- Core workflow system (Check_Do_Item and Set_Item_Properties callbacks)

**Outbound call tree:**
```
SAS_WORKFLOW_APPLIN_ACTION
├─ Has_Payday_Been_Run(pPaydayDate, pAgencyID) → boolean
│    ├─ [queries AGENCIES for final agency ID]
│    └─ [queries DC_BATCH_HEADERS, DC_BATCH_TYPES, AGENCIES]
├─ Check_Do_Item(pWorkPacketID) → (doItem, startNow, automatic)
│    ├─ SAS_WORKFLOW_APPLIN.Get_Application
│    ├─ [queries RATES for max(end_date) on CSS/PSS rate codes]
│    └─ Has_Payday_Been_Run (internal)
└─ Set_Item_Properties(pWorkPacketID)
     ├─ SAS_WORKFLOW_APPLIN.Get_Latest_Task
     ├─ SAS_WORKFLOW_APPLIN.Get_Previous_Task (×2)
     └─ [updates TASKS.USER_ID, TASKS.RESTRICTED_TO]
```

**Summary:** ACTION task handler determining eligibility to process a pension application based on payday run status and rate code currency.

---

### SAS_WORKFLOW_APPLIN_APPROVAL

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_WORKFLOW_APPLIN` — Reject_Approve (on delete/reenter)
- Core workflow system (Check_Do_Item, Set_Item_Properties, Next_Item callbacks)

**Outbound call tree:**
```
SAS_WORKFLOW_APPLIN_APPROVAL
├─ Check_Do_Item(pWorkPacketID) → Y/N
│    └─ SAS_WORKFLOW_APPLIN.Get_Application
├─ Set_Item_Properties(pWorkPacketID)
│    ├─ SAS_WORKFLOW_APPLIN.Get_Latest_Task / Get_Previous_Task
│    └─ [updates TASKS.RESTRICTED_TO]
├─ Next_Item(pWorkPacketID, pStatus) → next task name
│    ├─ SAS_WORKFLOW_APPLIN.Get_Application
│    ├─ SAS_WORKFLOW_APPLIN.Raise_Application_Error
│    └─ [returns AUTHORISE / ACTION (reject) / FINISH]
├─ Complete_Approve(pApplID)
│    ├─ [queries PAYMENTS, BENEFIT_REQUESTS]
│    └─ [updates PAYMENTS.DATE_APPROVED, APPROVAL_OFFICER_ID, PAYMENT_ITEMS.STATUS]
└─ Reject_Approve(pApplID)
     ├─ SAS_PAYMENT.Reject_Payment (per payment)
     ├─ [updates PAYMENT_ITEMS.STATUS]
     ├─ SAS_MEMBERSHIP_EXIT.Calc_Status_Rejected
     └─ [updates WORK_PACKETS.PRIORITY]
```

**Summary:** APPROVAL task handler routing approved applications to AUTHORISE or rejecting back to ACTION with payment status updates.

---

### SAS_WORKFLOW_APPLIN_RECONCILE

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_WORKFLOW_APPLIN` — Reject_RECONCILE
- Core workflow system (Check_Do_Item, Set_Item_Properties, Next_Item callbacks)

**Outbound call tree:**
```
SAS_WORKFLOW_APPLIN_RECONCILE
├─ Check_Do_Item(pWorkPacketID) → Y/Y/null
│    └─ SAS_WORKFLOW_APPLIN.Get_Application
├─ Set_Item_Properties(pWorkPacketID)   [no-op]
├─ Next_Item(pWorkPacketID, pStatus) → FINISH or ACTION
│    └─ SAS_WORKFLOW_APPLIN.Raise_Application_Error
└─ Reject_RECONCILE(pApplID)
     ├─ [queries PAYMENTS, CALCS_ANSWERS, CALCULATION_DATA]
     ├─ SAS_PAYMENT.Reject_Payment (per payment)
     ├─ [updates PAYMENT_ITEMS.STATUS, YEAR_TO_DATE_BALANCES]
     └─ SAS_MEMBERSHIP_EXIT.Exit_Status_Contributing / Exit_Status_Preserved
```

**Summary:** RECONCILE task handler validating paid payments with final reconciliation checks and membership status restoration on rejection.

---

### SAS_WORKFLOW_APPLIN_OFFLINE

**Outbound calls:** Yes

**Inbound callers:**
- Core workflow system (Set_Item_Properties, Next_Item callbacks)

**Outbound call tree:**
```
SAS_WORKFLOW_APPLIN_OFFLINE
├─ Set_Item_Properties(pWorkPacketID)
│    ├─ SAS_WORKFLOW_APPLIN.Get_Latest_Task / Get_Previous_Task
│    ├─ SAS_WORKFLOW_APPLIN.Get_Application
│    └─ [updates TASKS.RESTRICTED_TO, WORK_PACKETS.PRIORITY]
└─ Next_Item(pWorkPacketID, pStatus) → ACTION
     ├─ SAS_WORKFLOW_APPLIN.Get_Application
     └─ SAS_WORKFLOW_APPLIN.Raise_Application_Error
```

**Summary:** OFFLINEPMT task handler managing offline payment routing and inheriting task properties from the prior ACTION task.

---

### SAS_WORKFLOW_NBPO

**Outbound calls:** Yes

**Inbound callers:**
- Application layer (NBPO application — direct calls)

**Outbound call tree:**
```
SAS_WORKFLOW_NBPO
├─ Get_WorkPacket_ID(pAdvice_ID)
│    └─ [queries WORK_PACKETS, WORKFLOWS where job_type=NBPO]
├─ Check_Payment_Status(pWpID)
│    └─ [queries WORK_PACKETS, TASKS for PENDING_TASK_ID]
├─ Suspend_Payment(pWpID, pPendingReasonCode, pReason, pDaysToSuspend)
│    └─ SAS_WORKFLOW.Start_Pending
├─ Action_Next_Item / Approve_Next_Item / Authorise_Next_Item / Complete_Next_Item
│    └─ [returns next task name in chain]
├─ Start_Complete_Task(pAdvice_ID, pStatus)
│    ├─ Get_WorkPacket_ID (internal)
│    ├─ SAS_WORKFLOW.Start_Task
│    └─ SAS_WORKFLOW.Complete_Task
└─ Delete_WorkPacket(pAdvice_ID)
     └─ [deletes from TASKS, WORK_PACKETS where job_type=NBPO]
```

**Summary:** NBPO advice workflow orchestrator handling the action → approve → authorise → complete sequence with payment suspension capability.

---

### SAS_WORKFLOW_MANBP_AUTHORISE

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_WORKFLOW_MANBP2` — Reject_Authorise reference
- Core workflow system (Check_Do_Item, Set_Item_Properties, Next_Item callbacks)

**Outbound call tree:**
```
SAS_WORKFLOW_MANBP_AUTHORISE
├─ Check_Do_Item(pWorkPacketID) → Y/Y/null   [always eligible]
├─ Set_Item_Properties(pWorkPacketID)          [no-op]
├─ Next_Item(pWorkPacketID, pStatus) → RECONCILE or ACTION
│    └─ SAS_WORKFLOW_MANBP.Raise_Application_Error
├─ Complete_Authorise(pApplID)
│    ├─ [queries MANBP_PAYMENTS, MANBP_RESULTS]
│    └─ [updates MANBP_PAYMENTS.DATE_AUTHORISED]
└─ Reject_Authorise(pApplID)
     ├─ SAS_WORKFLOW_MANBP2.Get_Application_From_Appl_ID
     ├─ SAS_PAYMENT.Reject_Payment
     ├─ [updates MANBP_RESULTS.PROCESSING_STATUS, MANBP_PAYMENT_ITEMS.STATUS]
     ├─ SAS_MEMBERSHIP_EXIT.Exit_Status_Contributing / Exit_Status_Preserved
     └─ [updates WORK_PACKETS.PRIORITY]
```

**Summary:** ManBP AUTHORISE task handler setting payment authorisation date and handling rejection with membership status restoration.

---

### SAS_WORKFLOW_MANBP2

**Outbound calls:** Yes

**Inbound callers:**
- `SAS_WORKFLOW_MANBP_AUTHORISE` — Get_Application_From_Appl_ID

**Outbound call tree:**
```
SAS_WORKFLOW_MANBP2
├─ Get_Application(pWorkPacketID) [two overloads]
│    ├─ [queries WORK_PACKETS, WORKFLOWS, MANBP_APP_DETAILS]
│    └─ SAS_WORKFLOW_MANBP.Raise_Application_Error (validation failure)
├─ Get_Application_From_Mshp_ID(pMshpID) [two overloads]
│    ├─ [queries WP_MANBP_1 view]
│    └─ Get_Application (internal)
├─ Get_Previous_Task / Get_Latest_Task(pWorkPacketID, pTaskName)
│    └─ [queries TASKS ordered by START_DATE desc / ID asc]
└─ Suspend_Application(pWorkPacketID, pPendingReasonCode, pExplanation, pDaysToSuspend)
     ├─ [queries WP_MANBP_1]
     ├─ SAS_WORKFLOW_MANBP.Raise_Application_Error
     └─ SAS_WORKFLOW.Start_Pending
```

**Summary:** ManBP workflow helper providing application/task retrieval (Get_Application, Get_Latest_Task, Get_Previous_Task) and suspension capability.

---

### SAS_WORKFLOW_ABLE_TO_START

**Outbound calls:** No

**Inbound callers:**
- None detected (called by nightly batch job)

**Outbound call tree:**
```
SAS_WORKFLOW_ABLE_TO_START
├─ Update_Applin
│    ├─ [queries WORKFLOWS, WORK_PACKETS, TASKS, BEN_APPLICATIONS]
│    ├─ [compares pres_claim_date/exit_date against max(end_date) from RATES]
│    └─ [updates TASKS.ABLE_TO_START='Y'; commits]
└─ Update_Manbp
     ├─ [queries WORKFLOWS, WORK_PACKETS, TASKS, MANBP_APP_DETAILS]
     ├─ [compares pres_claim_date/exit_date against max(end_date) from RATES]
     └─ [updates TASKS.ABLE_TO_START='Y'; commits]
```

**Summary:** Nightly batch procedure enabling workflow tasks to proceed once application dates become eligible against the Rates table pension rate end dates.

---

## Group 7 — Estimation / Ready-Reckoner

---

### MILX_READY_RECKONER

**Outbound calls:** Yes

**Inbound callers:**
- `MILX_ACCESS_BYPASS` — display (staff bypass entry)

**Outbound call tree:**
```
MILX_READY_RECKONER
├─ get_scheme(pService, pRefNum) → integer
│    ├─ [queries SAS_Globals for MIL_I_ESTIMATOR_YEAR]
│    └─ [queries ZCS_MS_Common ⟕ ZCS_MS_MSBS_Cont / ZCS_MS_DFRDB_Cont]
├─ display(pService, pRefNum, pAccessNum, pType, pButton)
│    ├─ SAS_CBA_COMMON.ResetScreenNames
│    ├─ get_scheme (internal)
│    ├─ MILX_COMMON.check_access
│    ├─ [inserts MILX_AUDIT record]
│    ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
│    └─ [disclaimer HTML rendering]
├─ process(pService, pRefNum, pAccessNum, pType, pScheme, pButton)
│    ├─ MILX_COMMON.check_access
│    └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
└─ continue(pService, pRefNum, pAccessNum, pScheme, pButton)
     ├─ MILX_COMMON.check_access
     ├─ MILX_COMMON.Populate_year (scheme 1/4)
     └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display (frameset HTML)
```

**Summary:** MILX ready reckoner web interface controller managing access checks, scheme detection (MSBS/DFRDB), and HTML screen rendering for military pension estimation.

---

### MIEP_ESTIMATES

**Outbound calls:** No

**Inbound callers:**
- `MIEP_SUMMARY` — PSS_Ben_Estimates

**Outbound call tree:**
```
MIEP_ESTIMATES
├─ Check_For_Error
│    └─ [raises geErrorFound if gErrMesg is not null]
└─ PSS_Ben_Estimates(pExitDate, pMSDate, pBirthDate, pEligibleDate, ... [34 params])
     ├─ [queries RATES for ABM, FAS, product contribution rates]
     ├─ [complex pension/lumpsum calculation with tax implications]
     └─ [returns pPSSResults array — age-based benefit estimates]
```

**Summary:** PSS benefit estimation engine calculating retirement, death, invalidity, and preservation benefits with pension/lump sum options across multiple exit ages.

---

### MIEP_PRES_ESTIMATES

**Outbound calls:** Yes

**Inbound callers:**
- Web application (MIEP preserved member estimator forms)

**Outbound call tree:**
```
MIEP_PRES_ESTIMATES
├─ Check_For_Error
│    └─ [raises geErrorFound if gErrMesg is not null]
└─ PSS_Ben_Estimates(pClaimDate, pMSDate, pBirthDate, pEligibleDate, ... [31 params])
     ├─ MIEX_COMMON.TaxStartDateOK
     ├─ [queries RATES for rates and adjustment factors]
     ├─ [calculates unvested, invalidity, death benefit options]
     └─ [returns pPSSResults array — claim-age-based estimates]
```

**Summary:** PSS preserved member benefit estimator for claim date scenarios with invalidity and death protection options.

---

### MIEP_SUMMARY

**Outbound calls:** Yes

**Inbound callers:**
- Web application (PSS estimator display controller)

**Outbound call tree:**
```
MIEP_SUMMARY
├─ display_retirement(pPSSDetailsRec, pCalcResults, pPenPct, pLsPct)
│    └─ HTP.p (multiple — HTML rows for benefit options)
├─ display_pres_part(pPSSDetailsRec, pCalcResults, pPenPct, pLsPct)
│    └─ HTP.p (multiple)
└─ DisplayScreen(pPSSDetailsRec)
     ├─ MIEP_ESTIMATES.PSS_Ben_Estimates
     ├─ MIEX_COMMON.GetPresDate
     ├─ display_retirement / display_pres_part (internal, conditional)
     ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
     └─ [routes based on benefit option selected]
```

**Summary:** PSS benefit summary display controller rendering retirement/preservation benefit results across multiple exit ages using HTP for web output.

---

### MIEC_SUMMARY

**Outbound calls:** Yes

**Inbound callers:**
- Web application (CSS estimator display controller)

**Outbound call tree:**
```
MIEC_SUMMARY
├─ DisplayMaxPension / DisplayProdPension / DisplayStdPension / DisplayDeferred
│    ├─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
│    └─ HTP.p (multiple — benefit rows)
└─ DisplayScreen(pCSSDetailsRec)
     ├─ MIEC_ESTIMATES.CSS_Summary_Estimates
     ├─ [routing to DisplayMax/DisplayProd/DisplayStd/DisplayDeferred based on option]
     └─ SAS_CBA_HTML.ReadFile / ReplaceValue / Display
```

**Summary:** CSS benefit summary display controller rendering standard/maximum/productivity pension options and deferred benefit claims.

---

### MILD_BENEFIT_SUMMARY

**Outbound calls:** Yes

**Inbound callers:**
- Web application (DFRDB estimator display controller)

**Outbound call tree:**
```
MILD_BENEFIT_SUMMARY
├─ DisplayBenefit(pDFRDBDetailsRec)
│    ├─ MILD_ESTIMATES.DFRDB_Ben_Estimate
│    ├─ SAS_CBA_HTML.ReplaceValue / Display
│    └─ MILX_COMMON.DisplayError (on error)
└─ DisplayScreen(pDFRDBDetailsRec)
     ├─ SAS_CBA_COMMON.ResetScreenNames
│    ├─ SAS_CBA_HTML.ReadFile
│    ├─ SAS_CBA_COMMON.ReplaceScreenNames
│    ├─ SAS_CBA_HTML.ReplaceValue (multiple field replacements)
│    ├─ [cursor loop over promotion dates]
│    ├─ DisplayBenefit (internal)
│    ├─ MILX_COMMON.get_dfrdb_book_index
│    └─ SAS_CBA_HTML.Display
```

**Summary:** DFRDB (MILD scheme) benefit summary display controller with military rank/service validation and effective salary-based pension calculation rendering.

---

### MIEC_ESTIMATES

**Outbound calls:** Yes

**Inbound callers:**
- `MIEC_SUMMARY` — CSS_Summary_Estimates (called from DisplayScreen)

**Note:** Previously undocumented. Captured from source (`miec_estimates.pkb`). Internal service — not an entry point.

**Outbound call tree:**
```
MIEC_ESTIMATES
├─ CSS_Ben_Estimates(pDateCommence, pBirthDate, pContServYrs, pContServDays,
│                    pSuperSalary, pBasicCI, pSuppCI, pProdCI, pSuppConts,
│                    pBCCflg, pExPAflg, pScheme, pNTGovtFlg, pContsPost83,
│                    pUnfProdCI, pSGtopup, pSGpres, pSISlimit, pRestUnits,
│                    pRejUnits, pContRate, pCPI, pAWOTE, pBondRate,
│                    pHrsRatio, pInfoDate, pExitDate, pExitType, pClaimDate,
│                    pTaxStartDate, pDeflate, pCSSCalcResults, pErrMesg)
│    ├─ miex_common.CalcProdRate
│    ├─ miex_common.TaxStartDateOK
│    ├─ miex_common.DaysDifference (×3)
│    ├─ miex_common.GetPresDate
│    ├─ miex_common.findnextbday
│    ├─ miex_common.ProjectInt (×4)
│    ├─ miex_common.CalcComponent (×4)
│    ├─ miex_common.CalcConts (×2)
│    ├─ miex_common.IncreaseProd
│    ├─ miec_common.CalcProvAccPens          (ex-PA member)
│    ├─ miec_common.CalcPre76Pens            (pre-1976 commencer)
│    ├─ miec_common.Pre76PenRNR              (pre-76 with restricted/rejected units)
│    ├─ miec_common.CalcPost76Pens           (post-1976 commencer)
│    ├─ miec_common.CalcMaxPen (×2)
│    ├─ miec_common.calcinvalidpens          (INVALIDITY or DEATH)
│    ├─ miec_common.Get_Concessional_Days    (INVALIDITY, member under 65)
│    ├─ miec_common.DeferPenFactor           (DEFERRED)
│    ├─ MIEC_TAX.Tax_On_Member               (RESIGNATION)
│    ├─ MIEC_TAX.Tax_On_MaxPenLS             (RETIREMENT/RETRENCHMENT at/after pres age)
│    ├─ MIEC_TAX.Tax_On_MaxPenLS_Pre_PresAge (RETIREMENT/RETRENCHMENT before pres age)
│    ├─ MIEC_TAX.Tax_On_Inv_MaxPenLS         (INVALIDITY)
│    ├─ MIEC_TAX.Tax_On_ProdPenLS            (RETIREMENT/RETRENCHMENT at/after pres age)
│    ├─ MIEC_TAX.Tax_On_ProdPenLS_Pre_PresAge(RETIREMENT/RETRENCHMENT before pres age)
│    ├─ MIEC_TAX.Tax_On_StdPenLS             (RETIREMENT/RETRENCHMENT/INVALIDITY at/after pres age)
│    ├─ MIEC_TAX.Tax_On_StdPenLS_Pre_PresAge (RETIREMENT/RETRENCHMENT before pres age)
│    ├─ MIEC_TAX.Tax_On_FullLumpSum          (RETRENCHMENT/ex-PA RETIREMENT at/after pres age)
│    ├─ MIEC_TAX.Tax_On_FullLumpSum_Pre_PresAge (RETRENCHMENT/ex-PA RETIREMENT before pres age)
│    └─ deflate (internal nested function — deflates to today's dollars if pDeflate != 'Y')
└─ CSS_Summary_Estimates(pDateCommence, pBirthDate, ... pCSSSummaryResults, pErrMesg)
     ├─ miex_common.GetPresDate
     ├─ Check_For_Error (internal)
     └─ CSS_Ben_Estimates (internal, loop age 55→70; 55→65 for deferred)
```

**Summary:** CSS benefit estimation engine for the i-Estimator. Calculates pension and lump sum amounts for all exit types (resignation, retirement, retrenchment, invalidity, death, deferred) and delegates lump sum tax apportionment to MIEC_TAX.

---

### MIEC_TAX

**Outbound calls:** Yes

**Inbound callers:**
- `MIEC_ESTIMATES` — CSS_Ben_Estimates calls Tax_On_* procedures for each benefit option

**Note:** Previously undocumented. Captured from source (`miec_tax.pkb`). Internal service — not an entry point.

**Outbound call tree:**
```
MIEC_TAX
├─ Tax_On_FullLumpSum(pExitType, vBasicComp, vUnfProd, vPre83Days, vPost83Days,
│                     vUDC, vConcessionalDays, pInfoDate, pBirthDate, pExitDate,
│                     pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax
├─ Tax_On_FullLumpSum_Pre_PresAge(vBasicComp, vUnfProd, vPre83Days, vPost83Days,
│                                 vUDC, pInfoDate, pBirthDate, pExitDate,
│                                 pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax  (conditional: UDC does not cover full lump sum)
├─ Tax_On_MaxPenLS(vBasicComp, vSuppComp, vProdComp, vUnfProd, vPre83Days,
│                  vPost83Days, vUDC, vAddMaxLSum, pInfoDate, pBirthDate,
│                  pExitDate, pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax  (conditional: lump sum > 0)
├─ Tax_On_MaxPenLS_Pre_PresAge(...)
│    └─ miex_common.ProcessTax  (conditional: lump sum > 0 and UDC does not cover full amount)
├─ Tax_On_Inv_MaxPenLS(pExitType, vUnfProd, vPre83Days, vPost83Days, vUDC,
│                      vConcessionalDays, pInfoDate, pBirthDate, pExitDate,
│                      pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax
├─ Tax_On_ProdPenLS(vBasicComp, vSuppComp, vUnfProd, vPre83Days, vPost83Days,
│                   vUDC, vMembPenLS, pInfoDate, pBirthDate, pExitDate,
│                   pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax
├─ Tax_On_ProdPenLS_Pre_PresAge(...)
│    └─ miex_common.ProcessTax  (conditional: UDC does not cover full lump sum)
├─ Tax_On_StdPenLS(pExitType, vUnfProd, vPre83Days, vPost83Days, vUDC,
│                  vConcessionalDays, pInfoDate, pBirthDate, pExitDate,
│                  pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax
├─ Tax_On_StdPenLS_Pre_PresAge(vUnfProd, vPre83Days, vPost83Days, vUDC,
│                               pInfoDate, pBirthDate, pExitDate,
│                               pCSSCalcResults, pErrMesg)
│    └─ miex_common.ProcessTax  (conditional: UDC does not cover full lump sum)
└─ Tax_On_Member(vPre83Days, vPost83Days, vUDC, pInfoDate, pBirthDate,
                 pExitDate, pCSSCalcResults, pErrMesg)
     └─ miex_common.ProcessTax  (conditional: UDC does not cover full benefit)
```

**Summary:** CSS lump sum tax apportionment engine. Decomposes each lump sum into pre-1983, post-1983 funded, post-1983 unfunded, undeducted contributions, and post-1994 invalidity components, then delegates final tax calculation to MIEX_COMMON.ProcessTax.

---

### MIEC_COMMON

**Outbound calls:** Yes

**Inbound callers:**
- `MIEC_ESTIMATES` — CSS_Ben_Estimates calls pension formula functions

**Note:** Previously undocumented. Captured from source (`miec_common.pkb`). Internal service — not an entry point.

**Outbound call tree:**
```
MIEC_COMMON
├─ CalcMaxPen(pExitAge, pTotalComps, pFinalSalary, pPensionPct, pPensionFlg,
│             pPenMoney, pRefundAmt, pErrMesg) → number
│    └─ [queries Civc_AdditPens for ContPct, SalaryPct by RetireAge]
├─ CalcPost76Pens(pExitAge, pService, pFinalSalary, pPensionPct, pPensionFlg,
│                 pPenMoney, pErrMesg) → number
│    └─ [inline formula: 3 service brackets × age reduction]
├─ CalcPre76Pens(pExitAge, pService, pFinalSalary, pPensionPct, pPensionFlg,
│                pPenMoney, pErrMesg) → number
│    ├─ Pre76PensMult (internal)
│    └─ Pre76AddAmt (internal, conditional: service < 20 years)
├─ Pre76PensMult(pExitAge, pService, pErrMesg) → number
│    └─ [inline formula: 3 service brackets × age reduction]
├─ Pre76AddAmt(pExitYears, pExitDays, pErrMesg) → number
│    └─ [inline formula: $39/yr ages 31-60, additional $26/yr ages 60-65]
├─ CalcProvAccPens(pExitAge, pService, pFinalSalary, pPensionPct, pPensionFlg,
│                  pPenMoney, pErrMesg) → number
│    └─ [inline formula: ex-PA multiple × salary]
├─ CalcInvalidPens(pInfoDate, pExitDate, pBirthDate, pCommenceDate, pService,
│                  pHrsRatio, pExPAFlg, pDeductFlg, pStdPenFactor,
│                  pAddPenFactor, pErrMesg)
│    ├─ miex_common.DaysDifference (×2)
│    └─ [inline formula: prospective service to age 65 × membership category branch]
├─ DeferPenFactor(pDeferAge, pErrMesg) → number
│    └─ [inline lookup: age 55→9.25%, 56→9.40% ... 65+→11.00%]
├─ Pre76PenRNR(pServicePost76, pRejected, pRestricted, pRetireAge,
│              pPenAmount, pErrMesg) → number
│    └─ [inline formula: rejected unit deduction then restricted unit % reduction]
├─ CalcLumpSum(pBirthDate, pExitDate, pBasicAmt, pSuppAmt, pProdAmt,
│              pSISLimit, pLSumAmt, pROverAmt, pErrMesg)
│    ├─ miex_common.getpresdate
│    └─ miex_common.DaysDifference (×2)
└─ Get_Concessional_Days(pAge65ExitDate, pExitDate, pErrMesg) → number
     └─ [inline: pAge65ExitDate - pExitDate]
```

**Summary:** CSS pension formula library. Encodes all actuarial formulas for CSS standard pension (pre-1976, post-1976, ex-PA), maximum pension, invalidity pension factors, deferred benefit conversion, and lump sum calculation. Contains no web or display logic — pure calculation only.

---

### MIEX_COMMON

**Outbound calls:** No

**Inbound callers:**
- `MIEC_ESTIMATES` — CalcComponent, CalcConts, CalcProdRate, DaysDifference, GetPresDate, IncreaseProd, ProjectInt, TaxStartDateOK, findnextbday
- `MIEC_TAX` — ProcessTax
- `MIEC_COMMON` — CalcLumpSum (getpresdate, DaysDifference), CalcInvalidPens (DaysDifference)
- `MIEP_ESTIMATES` — GetPresDate, DaysDifference, ProjectInt, and economic globals
- `MIEP_PRES_ESTIMATES` — TaxStartDateOK, and economic globals
- `MIEC_SUMMARY` — gInterest, gCPI, gAWOTE globals (default values for display)

**Note:** Previously undocumented — captured from source (`miex_common.pkb`). Shared calculation foundation for all civilian i-Estimator packages (CSS and PSS). Internal service — not an entry point.

**Outbound call tree:**
```
MIEX_COMMON
├─ DaysDifference(pFirstDate, pSecondDate, pErrMesg) → number
│    └─ [inline: abs(Julian(pSecondDate) − Julian(pFirstDate))]
├─ GetPresDate(pBirthDate, pErrMesg) → date
│    └─ [inline lookup: born <Jul-1960→age 55; Jul1960-Jun1961→56; ...; Jul1964+→60; leap-year aware]
├─ FindNextBday(pBirthDate, pInfoDate, pErrMesg) → date
│    └─ [inline: next anniversary of pBirthDate after pInfoDate; handles 29-Feb]
├─ Inflate(pAmount, pInfoDate, pExitDate, pErrMesg) → number
│    ├─ DaysDifference (internal)
│    └─ [formula: amount × (1 + gCPI/100)^(days/365.25)]
├─ Deflate(pAmount, pInfoDate, pExitDate, pErrMesg) → number
│    ├─ DaysDifference (internal)
│    └─ [formula: amount ÷ (1 + gCPI/100)^(days/365.25)]
├─ ProjectCash(pAmount, pInfoDate, pCalcDate, pErrMesg) → number
│    ├─ DaysDifference (internal)
│    └─ [formula: amount × (1 + gAWOTE/100)^(days/365.25)]
├─ ProjectInt(pAmount, pInfoDate, pCalcDate, pErrMesg) → number    [overload 1 — global rate]
│    ├─ DaysDifference (internal)
│    └─ [formula: amount × (1 + gInterest/100)^(days/365.25)]
├─ ProjectInt(pAmount, pInfoDate, pCalcDate, pRate, pErrMesg) → number    [overload 2 — supplied rate]
│    ├─ DaysDifference (internal)
│    └─ [formula: amount × (1 + pRate/100)^(days/365.25)]
├─ CalcComponent(pSalary, pContRate, pInfoDate, pExitDate, pBirthDate, pMBLDate, pErrMesg) → number
│    ├─ FindNextBday (internal)
│    ├─ DaysDifference (internal, ×3)
│    ├─ ProjectInt (internal, conditional: MBL date applies)
│    └─ [combined AWOTE+interest geometric series; two formula variants; MBL date cap supported]
├─ CalcConts(pSalary, pContRate, pInfoDate, pExitDate, pBirthDate, pErrMesg) → number
│    ├─ FindNextBday (internal)
│    ├─ DaysDifference (internal, ×2)
│    └─ [contributions without interest — AWOTE growth only; used for UDC]
├─ CalcTFThreshold(pThreshold, pMSDate, pExitDate, pErrMesg) → number
│    ├─ DaysDifference (internal)
│    └─ [formula: threshold × (1 + gAWOTE/100)^(years)]
├─ ProcessTax(pFundedAmt, pUnfundedAmt, pBirthDate, pMSDate, pExitDate, pErrMesg) → number
│    ├─ CalcTFThreshold (internal)
│    └─ [age-based tax: under-55 funded 21.5%/unfunded 31.5%;
│        over-55 funded 0%/16.5% (threshold), unfunded 16.5%/31.5% (threshold)
│        TF threshold $117,576 (2003) projected by AWOTE to exit date]
├─ CalcProdRate(pSalary, pErrMesg) → number
│    └─ [2003 fortnightly salary brackets: <$1,337.33→$40.12 flat; $1,337–$2,155→3%;
│        $2,155–$3,233→$64.66 flat; $3,233+→2%]
├─ IncreaseProd(pProdAmount, pErrMesg) → number
│    └─ [formula: pProdAmount × (1 + (gInterest/100) × 15/170)
│        actuarial compensation for early tax removal on productivity contributions]
└─ TaxStartDateOK(pTaxStartDate, pBirthDate, pEligibleDate, pErrMesg) → boolean
     └─ [validates: pTaxStartDate >= 14th birthday AND <= pEligibleDate]
```

**Summary:** Shared mathematical foundation for the civilian i-Estimator (CSS and PSS). Owns the economic assumption globals (CPI, AWOTE, interest rate) and provides all core projection, tax, preservation age, and contribution calculation functions. No database queries or display logic.

---

### MIEX_SCREEN_COMMON

**Outbound calls:** No

**Inbound callers:**
- `MIEX_LOGIN` — populate_yr called at every login entry point
- `MIEC_SCREEN_COMMON` — populate_yr called in Startup
- `MIEC_DEFER_SCREEN_COMMON` — populate_yr called in Startup
- `MIEP_SCREEN_COMMON` — populate_yr called in Startup
- `MIEP_PRES_SCREEN_COMMON` — populate_yr called in Startup

**Note:** Previously undocumented — captured from source (`miex_screen_common.pkb`). Internal service — not an entry point. `ValidDate` function referenced by callers but absent from available body file.

**Outbound call tree:**
```
MIEX_SCREEN_COMMON
├─ gcStmtYR  varchar2  [package global — current i-Estimator statement year]
│             loaded by populate_yr; read directly by all CSS/PSS i-Estimator screen packages
│             used as: to_date('3006' || gcStmtYR, 'ddmmyyyy') → 30 June information date
└─ populate_yr
     └─ [queries SAS_Globals where global_name = 'I_ESTIMATOR_YEAR']
```

**Summary:** Statement year cache for the civilian i-Estimator. Holds `gcStmtYR` (loaded from `SAS_Globals`) used by all CSS and PSS i-Estimator screen packages to construct the 30 June information date and display the current statement year.

