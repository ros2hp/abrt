procedure Diag(Message in varchar2) is
begin
  DBMS_OUTPUT.PUT (Message);
  DBMS_OUTPUT.NEW_LINE;
end Diag;

procedure Accumulate_One_Member (
          pMembershipID         in Memberships.ID%type,
          pStartDate            in date,
          pEndDate              in date,
          pFirstCall            in boolean,
          pDays                out number,
          pDuesID              out Dues.ID%type,
          pPres170             out boolean,
	  pPres46	       out boolean,
          pPresRestricted      out boolean,
          pPriorContribService out Old_Preservations.Prior_Contrib_Service%type,
          pStatus              out varchar2) is
  vDuesID   Dues.id%type;
  vDueRec   Dues%rowtype;
  vPrevRec  Dues%rowtype;
  vTesting    boolean := false;
  vStatus     varchar2(1)  := 'N';
  vLastDate   date;
  vTermDate   date;
  vJoinDate   date;
  vStDteFound boolean := false;
  vSumDays    number(10,4) := 0.0;
  vScheme Schemes.Short_Name%type;
  vSrvcDays    Prior_Services.Service_Days%type;
  vSumSrvcDays Prior_Services.Service_Days%type := 0;
  vPreservationCode       Old_Preservations.Preservation_Code%type;
  vRestrictionInUE        Old_Preservations.Restriction_In_UE%type;
  vPriorContribService    Old_Preservations.Prior_Contrib_Service%type :=0;
  vSumPriorContribService Old_Preservations.Prior_Contrib_Service%type :=0;
  vPres170                boolean := false;
  vPres46                 boolean := false;
  vPresRestricted         boolean := false;
  vBirthDate	          date;
  vPrevJoinDate           date;
  vPrevExitDate           date;
  vFromDate               date;
  vToDate                 date;

  cursor crScheme is
    select s.Short_Name
      from Schemes s,
           Memberships m
     where m.ID = pMembershipID
       and s.ID = m.Sch_ID;

  cursor crPriorSrvc is
    select Service_Days, Service_From_Date, Service_To_Date
      from Prior_Services
     where mShp_ID = pMembershipID;

  cursor crOldPres is
    select Preservation_Code,
           Restriction_In_UE,
           Prior_Contrib_Service
      from Old_Preservations
     where Mshp_ID = pMembershipID;

  cursor crDues is
    select *
      from Dues
     where ID = vDuesID
       and Source_Entity in ('M','E','I')
     order by Init_Contrib_Date,
              Start_Date,
              Source_Entity Desc;

  cursor crBirthDate is
    select P.Birth_Date
      from People P,
           Memberships M
     where M.ID = pMembershipID
       and M.Per_ID = P.ID;

  cursor crLinkDetails is
    select join_date, exit_date
      from memberships m
     where id in (select L.From_Account_ID
                   from Links L,
                        Link_Types T
                  where L.To_Account_id = pMembershipID
                    and L.lnktyp_ID = T.ID
                    and T.Service_Carried_Flag = 'Y'
                    and L.Link_ID is null
                    and L.Reversed = 'N'
                    and L.Status = 'COMP'
                    and l.lnktyp_id = 3);

begin

  if vTesting then
     Diag('_____________________One Member');
  end if;

  pStatus := 'N';

  /* Initialise flag to detect point where */
  /* parameter start date kicks in.        */

  vStDteFound := false;
  if pEndDate is null then
     vStDteFound := true;
  end if;

  /* Added by M. Gore
     If a dues start date is the birthdate then the record
     will not be counted */

  open crBirthDate;
  fetch crBirthDate into vBirthDate;
  close crBirthDate;

  /* Check that the Scheme is CSS */

  open crScheme;
  fetch crScheme
    into vScheme;
  close crScheme;
  if vScheme != 'CSS' then
     return;
  end if;

  /* Create a Dues history for the Member */
  if Calcs_Load.gCSSDuesID is null then
     SAS_Membership_Dues.Get_Dues (PMembershipID,vDuesID,vStatus);
  else 
     vDuesID := Calcs_Load.gCSSDuesID;
     vStatus := 'Y';
  end if;

  pDuesID := vDuesID;
  if vStatus = 'N' then
     pStatus := vStatus;
     return;
  end if;

end;
