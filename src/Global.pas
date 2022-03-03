unit Global;

interface

uses SysUtils, interface_global;


Const 
      EvapZmin = 15; //cm  minimum soil depth for water extraction by evaporation

TYPE
     rep_TypeObsSim =(ObsSimCC,ObsSimB,ObsSimSWC);

VAR DataPath,ObsPath : BOOLEAN;
    SWCiniFileFull,ProjectFileFull,MultipleProjectFileFull : string;
    ProjectDescription, MultipleProjectDescription,
    GroundWaterDescription: string;

    RootingDepth   : double;
    CCiActual,CCiPrev,CCiTopEarlySen : double;

    SenStage       : INTEGER;
    DaySubmerged   : INTEGER;
    ETo, Epot, Tpot, Rain, Irrigation, Infiltrated, CRwater : double;   (* mm/day *)
    Tmin, Tmax : double; (* degC *)
    SurfaceStorage, Runoff, Drain, Eact, Tact, TactWeedInfested : double;        (* mm/day *)
    EvapoEntireSoilSurface : BOOLEAN; // True of soil wetted by RAIN (false = IRRIGATION and fw < 1)
    PreDay         : BOOLEAN;
    Surf0          : double; (* surface water [mm] begin day *)
    NrC,NrD        : INTEGER; (* formats REAL *)
    MinReal, MaxReal : double;
    MinInt, MaxInt : INTEGER;
    MaxPlotNew : Integer;
    MaxPlotTr : ShortInt;
    IniPercTAW : ShortInt; // Default Value for Percentage TAW for Initial Soil Water Content Menu
    // salinity
    ECstorage      : double; (* EC surface storage dS/m *)
    ECdrain        : double; (* EC drain water dS/m *)
    SaltInfiltr    : double; (* salt infiltrated in soil profile Mg/ha *)
    CRsalt         : double; // gram/m2
    ECiAqua        : double; //  EC of the groundwater table in dS/m




// Extra for stand alone procedure
    OutputAggregate : ShortInt;
    PathNameList,PathNameParam : string;
    Out1Wabal,Out2Crop,Out3Prof,Out4Salt,Out5CompWC,Out6CompEC,Out7Clim,OutDaily,
    Part1Mult,Part2Eval : BOOLEAN;

    Type
    repTypeProject = (TypePRO,TypePRM,TypeNone);


PROCEDURE LoadClim (FullName : string;
                    VAR ClimateDescription : string;
                    VAR ClimateRecord : rep_clim);
PROCEDURE AppendCropFilePerennials(totalname : string;
                                   GenrateTheOnset,GenerateTheEnd : BOOLEAN;
                                   CriterionNrOnset,Day1Onset,Month1Onset,LengthOnset,SuccessiveDaysOnset,OccurrenceOnset : INTEGER;
                                   CriterionNrEnd,DayNEnd,MonthNEnd,ExtraYearEnd,LengthEnd,SuccessiveDaysEnd,OccurrenceEnd : INTEGER;
                                   ThresholdOnset,ThresholdEnd : double);
PROCEDURE DetermineLinkedSimDay1(CropDay1 : LongInt;
                                 VAR SimDay1 :LongInt);

PROCEDURE AdjustSimPeriod;

PROCEDURE CheckForKeepSWC(FullNameProjectFile : string;
                          TotalNrOfRuns : INTEGER;
                          VAR RunWithKeepSWC : BOOLEAN;
                          VAR ConstZrxForRun : double);
PROCEDURE AdjustThetaInitial(PrevNrComp : ShortInt;
                             PrevThickComp,PrevVolPrComp,PrevECdSComp : rep_IniComp);
PROCEDURE AdjustSizeCompartments(CropZx : double);
PROCEDURE CheckForWaterTableInProfile(DepthGWTmeter : double;
                                     ProfileComp : rep_comp;
                                     VAR WaterTableInProfile : BOOLEAN);
PROCEDURE LoadGroundWater(FullName : string;
                          AtDayNr : LongInt;
                          VAR Zcm : INTEGER;
                          VAR ECdSm : double);

PROCEDURE GetFileForProgramParameters(TheFullFileNameProgram : string;
                                      VAR FullFileNameProgramParameters : string);


implementation







PROCEDURE LoadClim (FullName : string;
                    VAR ClimateDescription : string;
                    VAR ClimateRecord : rep_clim);
VAR f0 : TextFile;
    Ni : INTEGER;
BEGIN
Assign(f0,FullName);
Reset(f0);
READLN(f0,CLimateDescription);
READLN(f0,Ni);
IF (Ni = 1) THEN ClimateRecord.DataType := Daily
            ELSE IF (Ni = 2) THEN ClimateRecord.DataType := Decadely
                             ELSE ClimateRecord.DataType := Monthly;
READLN(f0,ClimateRecord.FromD);
READLN(f0,ClimateRecord.FromM);
READLN(f0,ClimateRecord.FromY);
READLN(f0);
READLN(f0);
READLN(f0);
ClimateRecord.NrObs := 0;
WHILE NOT Eof(f0) DO
      BEGIN
      ClimateRecord.NrObs := ClimateRecord.NrObs + 1;
      READLN(f0);
      END;
Close(f0);
CompleteClimateDescription(ClimateRecord);
END; // LoadClim



PROCEDURE AppendCropFilePerennials(totalname : string;
                                   GenrateTheOnset,GenerateTheEnd : BOOLEAN;
                                   CriterionNrOnset,Day1Onset,Month1Onset,LengthOnset,SuccessiveDaysOnset,OccurrenceOnset : INTEGER;
                                   CriterionNrEnd,DayNEnd,MonthNEnd,ExtraYearEnd,LengthEnd,SuccessiveDaysEnd,OccurrenceEnd : INTEGER;
                                   ThresholdOnset,ThresholdEnd : double);
VAR f : TextFile;
    TempString : string;
BEGIN
Assign(f,totalname);
Append(f);
// 1. Title
WRITELN(f); // empty line
WRITELN(f,' Internal crop calendar');
WRITELN(f,' ========================================================');

// 2. ONSET
// criterion number
IF (GenrateTheOnset = false)
   THEN BEGIN
        CriterionNrOnset := 0;
        TempString := '         : The Restart of growth is fixed on a specific date';
        END
   ELSE BEGIN
        CASE CriterionNrOnset OF
          12 : TempString := '         : The Restart of growth is generated by average air temperature';
          13 : TempString := '         : The Restart of growth is generated by Growing-degree days';
          else BEGIN // no valid criterion number
               GenrateTheOnset := false;
               CriterionNrOnset := 0;
               TempString := '         : The Restart of growth is fixed on a specific date';
               END;
          end;
        END;
WRITELN(f,CriterionNrOnset:6,TempString);

// parameters ONSET
IF (GenrateTheOnset = false)
   THEN BEGIN
        WRITELN(f,Day1Onset:6,'         : First Day of growth');
        WRITELN(f,Month1Onset:6,'         : First Month of growth');
        WRITELN(f,LengthOnset:6,'         : Length (days) for the time window (Restart of growth): Not Applicable');
        WRITELN(f,ThresholdOnset:8:1,'       : Threshold for the Restart criterion: Not Applicable');
        WRITELN(f,SuccessiveDaysOnset:6,'         : Number of successive days for the Restart criterion: Not Applicable');
        WRITELN(f,OccurrenceOnset:6,'         : Number of occurrences before the Restart criterion applies: Not Applicable');
        END
   ELSE BEGIN
        WRITELN(f,Day1Onset:6,'         : First Day for the time window (Restart of growth)');
        WRITELN(f,Month1Onset:6,'         : First Month for the time window (Restart of growth)');
        WRITELN(f,LengthOnset:6,'         : Length (days) of the time window (Restart of growth)');
        CASE CriterionNrOnset OF
          12 : TempString := '       : Threshold for the Restart criterion: Average air temperature (degC)';
          13 : TempString := '       : Threshold for the Restart criterion: Growing-degree days';
          end;
        WRITELN(f,ThresholdOnset:8:1,TempString);
        WRITELN(f,SuccessiveDaysOnset:6,'         : Number of successive days for the Restart criterion');
        IF (OccurrenceOnset > 3) THEN OccurrenceOnset := 3;
        WRITELN(f,OccurrenceOnset:6,'         : Number of occurrences before the Restart criterion applies');
        END;

// 3. END of growing period
// criterion number
IF (GenerateTheEnd = false)
   THEN BEGIN
        CriterionNrEnd := 0;
        TempString := '         : The End of growth is fixed on a specific date';
        END
   ELSE BEGIN
        CASE CriterionNrEnd OF
          62 : TempString := '         : The End of growth is generated by average air temperature';
          63 : TempString := '         : The End of growth is generated by Growing-degree days';
          else BEGIN // no valid criterion number
               GenerateTheEnd := false;
               CriterionNrEnd := 0;
               TempString := '         : The End of growth is fixed on a specific date';
               END;
          end;
        END;
WRITELN(f,CriterionNrEnd:6,TempString);

// parameters END of growing period
IF (GenerateTheEnd = false)
   THEN BEGIN
        WRITELN(f,DayNEnd:6,'         : Last Day of growth');
        WRITELN(f,MonthNEnd:6,'         : Last Month of growth');
        WRITELN(f,ExtraYearEnd:6,'         : Number of years to add to the Restart year');
        WRITELN(f,LengthEnd:6,'         : Length (days) for the time window (End of growth): Not Applicable');
        WRITELN(f,ThresholdEnd:8:1,'       : Threshold for the End criterion: Not Applicable');
        WRITELN(f,SuccessiveDaysEnd:6,'         : Number of successive days for the End criterion: Not Applicable');
        WRITELN(f,OccurrenceEnd:6,'         : Number of occurrences before the End criterion applies: Not Applicable');
        END
   ELSE BEGIN
        WRITELN(f,DayNEnd:6,'         : Last Day for the time window (End of growth)');
        WRITELN(f,MonthNEnd:6,'         : Last Month for the time window (End of growth)');
        WRITELN(f,ExtraYearEnd:6,'         : Number of years to add to the Onset year');
        WRITELN(f,LengthEnd:6,'         : Length (days) of the time window (End of growth)');
        CASE CriterionNrEnd OF
          62 : TempString := '       : Threshold for the End criterion: average air temperature (degC)';
          63 : TempString := '       : Threshold for the End criterion: Growing-degree days';
          end;
        WRITELN(f,ThresholdEnd:8:1,TempString);
        WRITELN(f,SuccessiveDaysEnd:6,'         : Number of successive days for the End criterion');
        IF (OccurrenceEnd > 3) THEN OccurrenceEnd := 3;
        WRITELN(f,OccurrenceEnd:6,'         : Number of occurrences before the End criterion applies');
        END;
Close(f);
END; (* AppendCropFilePerennials *)


PROCEDURE DetermineLinkedSimDay1(CropDay1 : LongInt;
                                 VAR SimDay1 :LongInt);
BEGIN
SimDay1 := CropDay1;
IF (GetClimFile() <> '(None)') THEN
   BEGIN
   (*
   IF SimDay1 < GetClimRecord_FromDayNr() THEN SimDay1 := GetClimRecord_FromDayNr();
   IF SimDay1 > GetClimRecord_ToDayNr()
      THEN BEGIN
           Simulation.LinkCropToSimPeriod := false;
           SimDay1 := GetClimRecord_FromDayNr();
           END; *)
   IF ((SimDay1 < GetClimRecord_FromDayNr()) OR (SimDay1 > GetClimRecord_ToDayNr())) THEN
      BEGIN
      SetSimulation_LinkCropToSimPeriod(false);
      SimDay1 := GetClimRecord_FromDayNr();
      END;
   END;
END; (* DetermineLinkedSimDay1 *)





PROCEDURE AdjustSimPeriod;
VAR IniSimFromDayNr : LongInt;
    FullFileName : string;
    FromDayNr_temp, ZiAqua_temp : integer;
    Compartment_temp : rep_Comp;

BEGIN
IniSimFromDayNr := GetSimulation_FromDayNr();
CASE GetSimulation_LinkCropToSimPeriod() OF
     true : BEGIN
            FromDayNr_temp := GetSimulation_FromDayNr();
            DetermineLinkedSimDay1(GetCrop().Day1,FromDayNr_temp);
            SetSimulation_FromDayNr(FromDayNr_temp);
            IF (GetCrop().Day1 = GetSimulation_FromDayNr())
               THEN SetSimulation_ToDayNr(GetCrop().DayN)
               ELSE SetSimulation_ToDayNr(GetSimulation_FromDayNr() + 30); // 30 days
            IF (GetClimFile() <> '(None)') THEN
               BEGIN
               IF (GetSimulation_ToDayNr() > GetClimRecord_ToDayNr()) THEN
                   SetSimulation_ToDayNr(GetClimRecord_ToDayNr());
               IF (GetSimulation_ToDayNr() < GetClimRecord_FromDayNr()) THEN
                      SetSimulation_ToDayNr(GetClimRecord_FromDayNr());
               END;
            END;
    false : BEGIN
            (*
            IF ((GetClimFile() <> '(None)') AND (Simulation.FromDayNr < GetClimRecord_FromDayNr())) THEN
               BEGIN
               Simulation.FromDayNr := GetClimRecord_FromDayNr();
               Simulation.ToDayNr := Simulation.FromDayNr + 30; // 30 days
               END; *)
            IF (GetSimulation_FromDayNr() > GetCrop().Day1) THEN SetSimulation_FromDayNr(GetCrop().Day1);
            SetSimulation_ToDayNr(GetCrop().DayN);
            IF ((GetClimFile() <> '(None)') AND
                ((GetSimulation_FromDayNr() <= GetClimRecord_FromDayNr()) OR (GetSimulation_FromDayNr() >= GetClimRecord_ToDayNr()))) THEN
               BEGIN
               SetSimulation_FromDayNr(GetClimRecord_FromDayNr());
               SetSimulation_ToDayNr(GetSimulation_FromDayNr() + 30); // 30 days
               END;
            END;
    end;

// adjust initial depth and quality of the groundwater when required
IF ((NOT GetSimulParam_ConstGwt()) AND (IniSimFromDayNr <> GetSimulation_FromDayNr())) THEN
   BEGIN
   IF (GetGroundWaterFile() = '(None)')
       THEN FullFileName := CONCAT(GetPathNameProg(),'GroundWater.AqC')
       ELSE FullFileName := GetGroundWaterFileFull();
   // initialize ZiAqua and ECiAqua
   ZiAqua_temp := GetZiAqua();
   LoadGroundWater(FullFileName,GetSimulation_FromDayNr(),ZiAqua_temp,ECiAqua);
   SetZiAqua(ZiAqua_temp);
   Compartment_temp := GetCompartment();
   CalculateAdjustedFC((GetZiAqua()/100),Compartment_temp);
   SetCompartment(Compartment_temp);
   IF GetSimulation_IniSWC_AtFC() THEN ResetSWCToFC;
   END;
END; (* AdjustSimPeriod *)




PROCEDURE CheckForKeepSWC(FullNameProjectFile : string;
                          TotalNrOfRuns : INTEGER;
                          VAR RunWithKeepSWC : BOOLEAN;
                          VAR ConstZrxForRun : double);
VAR f0,fx : TextFile;
    i,Runi : INTEGER;
    FileName,PathName,FullFileName : string;
    Zrni,Zrxi,ZrSoili : double;
    VersionNrCrop : double;
    TheNrSoilLayers : ShortInt;
    TheSoilLayer : rep_SoilLayer;
    PreviousProfFilefull : string;

BEGIN
//1. Initial settings
RunWithKeepSWC := false;
ConstZrxForRun := undef_int;

//2. Open project file
Assign(f0,FullNameProjectFile);
Reset(f0);
READLN(f0); // Description
READLN(f0);  // AquaCrop version Nr
FOR i := 1 TO 5 DO READLN(f0); // Type Year, and Simulation and Cropping period of run 1

//3. Look for restrictive soil layer
//restricted to run 1 since with KeepSWC, the soil file has to be common between runs
PreviousProfFilefull := GetProfFilefull(); // keep name soil file (to restore after check)
FOR i := 1 TO 27 DO READLN(f0); // Climate (5x3 = 15),Calendar (3),Crop (3), Irri (3) and Field (3) file
READLN(f0); // info Soil file
READLN(f0,FileName);
READLN(f0,PathName);
PathName := StringReplace(PathName, '"', '', [rfReplaceAll]);
FullFileName := CONCAT(Trim(PathName),Trim(FileName));
LoadProfile(FullFileName);
TheNrSoilLayers := GetSoil().NrSoilLayers;
TheSoilLayer := GetSoilLayer();
//ZrRestrict := 1000; // assumed not to be so far a restriction
(*
Assign(fx,FullFileName);
Reset(fx);
FOR i := 1 TO 5 DO READLN(fx);
READLN(fx,ZrRestrict); // depth restrictive soil layer inhibiting root zone expansion
IF (ZrRestrict < 0)
   THEN ZrRestrict := 1000 // undefined, HENCE very large (no restriction)
   ELSE IF (ZrRestrict <= 1.20) THEN ConstZrxForRun := ZrRestrict;
Close(fx); *)

//3.bis  groundwater file
FOR i := 1 TO 3 DO READLN(f0);

//4. Check if runs with KeepSWC exist
Runi := 1;
WHILE (RunWithKeepSWC = false) AND (Runi <= TotalNrOfRuns) DO
   BEGIN
   IF (Runi > 1) THEN FOR i := 1 TO 47 DO READLN(f0);  // 5 + 42 lines with files
   READLN(f0); // info Initial Conditions file
   READLN(f0,FileName);
   READLN(f0); //Pathname
   IF (Trim(FileName) = 'KeepSWC') THEN RunWithKeepSWC := true;
   Runi := Runi + 1;
   END;
IF (RunWithKeepSWC = false) THEN ConstZrxForRun := undef_int; // reset

//5. Look for maximum root zone depth IF RunWithKeepSWC
//IF (RunWithKeepSWC AND (ROUND(100*ConstZrxForRun) < ROUND(100*ZrRestrict))) THEN
IF (RunWithKeepSWC = true) THEN
   BEGIN
   Reset(f0);
   READLN(f0); // Description
   READLN(f0);  // AquaCrop version Nr
   FOR i := 1 TO 5 DO READLN(f0); // Type Year, and Simulation and Cropping period of run 1
   Runi := 1;
   //WHILE ((ROUND(100*ConstZrxForRun) < ROUND(100*ZrRestrict)) AND (Runi <= TotalNrOfRuns)) DO
   WHILE (Runi <= TotalNrOfRuns) DO
     BEGIN
     // Simulation and Cropping period
     IF (Runi > 1) THEN FOR i := 1 TO 5 DO READLN(f0);
     // 5 Climate files (15) + Calendar file (3)
     FOR i := 1 TO 18 DO READLN(f0);
     // Crop file
     READLN(f0); // Crop file title
     READLN(f0,FileName);
     READLN(f0,PathName);
     PathName := StringReplace(PathName, '"', '', [rfReplaceAll]);
     FullFileName := CONCAT(Trim(PathName),Trim(FileName));
     Assign(fx,FullFileName);
     Reset(fx);
     READLN(fx); // description
     READLN(fx,VersionNrCrop);
     IF (Round(VersionNrCrop*10) <= 31)
        THEN FOR i := 1 TO 29 DO READLN(fx)  // no Salinity stress (No Reponse Stomata + ECemin + ECemax + ShapeKsSalt)
        ELSE BEGIN
             IF (Round(VersionNrCrop*10) <= 50)
                THEN FOR i := 1 TO 32 DO READLN(fx) // no distortion to salinity and response to ECsw factor
                ELSE FOR i := 1 TO 34 DO READLN(fx);
             END;
     READLN(fx,Zrni); // minimum rooting depth
     READLN(fx,Zrxi); // maximum rooting depth
     ZrSoili := RootMaxInSoilProfile(Zrxi,TheNrSoilLayers,TheSoilLayer);
     IF (ZrSoili > ConstZrxForRun) THEN ConstZrxForRun := ZrSoili;
     Close(fx);
     // Remaining files: Irri (3), Field (3), Soil (3), Gwt (3), Inni (3), Off (3) and FieldData (3) file
     FOR i := 1 TO 21 DO READLN(f0);
     Runi := Runi + 1;
     END;
   END;
Close(f0);

//6. Reload existing soil file
SetProfFilefull(PreviousProfFilefull);
LoadProfile(GetProfFilefull());
END; (* CheckForKeepSWC *)




PROCEDURE AdjustThetaInitial(PrevNrComp : ShortInt;
                             PrevThickComp,PrevVolPrComp,PrevECdSComp : rep_IniComp);
VAR layeri,compi : INTEGER;
    TotDepthC,TotDepthL,Total : Double;
    Compartment_temp : rep_Comp;

BEGIN
//1. Actual total depth of compartments
TotDepthC := 0;
FOR compi := 1 to GetNrCompartments() DO TotDepthC := TotDepthC + GetCompartment_Thickness(compi);

//2. Stretch thickness of bottom soil layer if required
TotDepthL := 0;
For layeri := 1 to GetSoil().NrSoilLayers DO TotDepthL := TotDepthL + GetSoilLayer_i(layeri).Thickness;
IF (TotDepthC > TotDepthL) THEN SetSoilLayer_Thickness(GetSoil().NrSoilLayers, GetSoilLayer_i(GetSoil().NrSoilLayers).Thickness + (TotDepthC - TotDepthL));

//3. Assign a soil layer to each soil compartment
Compartment_temp := GetCompartment();
DesignateSoilLayerToCompartments(GetNrCompartments(),GetSoil().NrSoilLayers,Compartment_temp);
SetCompartment(Compartment_temp);

//4. Adjust initial Soil Water Content of soil compartments
IF GetSimulation_ResetIniSWC()
   THEN BEGIN
        IF GetSimulation_IniSWC_AtDepths()
           THEN BEGIN
                Compartment_temp := GetCompartment();
                TranslateIniPointsToSWProfile(GetSimulation_IniSWC_NrLoc(),GetSimulation_IniSWC_Loc(),GetSimulation_IniSWC_VolProc(),
                                              GetSimulation_IniSWC_SaltECe(),GetNrCompartments(),Compartment_temp);
                SetCompartment(Compartment_temp);
                END
           ELSE BEGIN
                Compartment_temp := GetCompartment();
                TranslateIniLayersToSWProfile(GetSimulation_IniSWC_NrLoc(),GetSimulation_IniSWC_Loc(),GetSimulation_IniSWC_VolProc(),
                                              GetSimulation_IniSWC_SaltECe(),GetNrCompartments(),Compartment_temp);
                SetCompartment(Compartment_temp);
                END;
        END
   ELSE BEGIN
        Compartment_temp := GetCompartment();
        TranslateIniLayersToSWProfile(PrevNrComp,PrevThickComp,PrevVolPrComp,PrevECdSComp,GetNrCompartments(),Compartment_temp);
        SetCompartment(Compartment_temp);
        END;

//5. Adjust watercontent in soil layers and determine ThetaIni
Total := 0;
FOR layeri := 1 TO GetSoil().NrSoilLayers DO SetSoilLayer_WaterContent(layeri, 0);
FOR compi := 1 TO GetNrCompartments() DO
    BEGIN
    SetSimulation_ThetaIni_i(compi,GetCompartment_Theta(compi));
    SetSoilLayer_WaterContent(GetCompartment_Layer(compi), GetSoilLayer_i(GetCompartment_Layer(compi)).WaterContent
                                                                + GetSimulation_ThetaIni_i(compi)*100*10*GetCompartment_Thickness(compi));
    END;
FOR layeri := 1 TO GetSoil().NrSoilLayers DO Total := Total + GetSoilLayer_i(layeri).WaterContent;
SetTotalWaterContent_BeginDay(Total);
END; (* AdjustThetaInitial *)




PROCEDURE AdjustSizeCompartments(CropZx : double);
VAR i ,compi : INTEGER;
    TotDepthC,fAdd : Double;
    PrevNrComp : ShortInt;
    PrevThickComp,PrevVolPrComp,PrevECdSComp : rep_IniComp;
BEGIN

//1. Save intial soil water profile (required when initial soil water profile is NOT reset at start simulation - see 7.)
PrevNrComp := GetNrCompartments();
FOR compi := 1 To prevnrComp DO
    BEGIN
    PrevThickComp[compi] := GetCompartment_Thickness(compi);
    PrevVolPrComp[compi] := 100*GetCompartment_Theta(compi);
    END;

//2. Actual total depth of compartments
TotDepthC := 0;
FOR i := 1 to GetNrCompartments() DO TotDepthC := TotDepthC + GetCompartment_Thickness(compi);

//3. Increase number of compartments (if less than 12)
IF (GetNrCompartments() < 12) THEN
   REPEAT
   SetNrCompartments(GetNrCompartments() + 1);
   IF ((CropZx - TotDepthC) > GetSimulParam_CompDefThick())
      THEN SetCompartment_Thickness(GetNrCompartments(), GetSimulParam_CompDefThick())
      ELSE SetCompartment_Thickness(GetNrCompartments(), CropZx - TotDepthC);
   TotDepthC := TotDepthC + GetCompartment_Thickness(GetNrCompartments());
   UNTIL ((GetNrCompartments() = max_No_compartments) OR ((TotDepthC + 0.00001) >= CropZx));

//4. Adjust size of compartments (if total depth of compartments < rooting depth)
IF ((TotDepthC + 0.00001) < CropZx) THEN
   BEGIN
   SetNrCompartments(12);
   fAdd := (CropZx/0.1 - 12)/78;
   FOR i := 1 TO 12 DO
       BEGIN
       SetCompartment_Thickness(i, 0.1 * (1 + i*fAdd));
       SetCompartment_Thickness(i, 0.05 * ROUND(GetCompartment_Thickness(i) * 20));
       END;
   TotDepthC := 0;
   FOR i := 1 to GetNrCompartments() DO TotDepthC := TotDepthC + GetCompartment_Thickness(i);
   IF (TotDepthC < CropZx)
      THEN REPEAT
           SetCompartment_Thickness(12, GetCompartment_Thickness(12) + 0.05);
           TotDepthC := TotDepthC + 0.05;
           UNTIL (TotDepthC >= CropZx)
      ELSE WHILE ((TotDepthC - 0.04999999) >= CropZx) DO
               BEGIN
               SetCompartment_Thickness(12, GetCompartment_Thickness(12) - 0.05);
               TotDepthC := TotDepthC - 0.05;
               END;
   END;

//5. Adjust soil water content and theta initial
AdjustThetaInitial(PrevNrComp,PrevThickComp,PrevVolPrComp,PrevECdSComp);
END; (* AdjustSizeCompartments *)


PROCEDURE CheckForWaterTableInProfile(DepthGWTmeter : double;
                                     ProfileComp : rep_comp;
                                     VAR WaterTableInProfile : BOOLEAN);
Var Ztot, Zi : double;
    compi : INTEGER;
BEGIN
WaterTableInProfile := false;
Ztot := 0;
compi := 0;
IF (DepthGWTmeter >= 0) THEN  // groundwater table is present
   REPEAT
   compi := compi + 1;
   Ztot := Ztot + ProfileComp[compi].Thickness;
   Zi := Ztot - ProfileComp[compi].Thickness/2;
   IF (Zi >= DepthGWTmeter) THEN WaterTableInProfile := true;
   UNTIL ((WaterTableInProfile = true) OR (compi >= GetNrCompartments()));
END; (* CheckForWaterTableInProfile *)




PROCEDURE LoadGroundWater(FullName : string;
                          AtDayNr : LongInt;
                          VAR Zcm : INTEGER;
                          VAR ECdSm : double);
VAR f0 : TextFile;
    i,dayi,monthi,yeari,Year1Gwt : INTEGER;
    DayNr1Gwt,DayNr1,DayNr2,DayNrN : LongInt;
    StringREAD : ShortString;
    DayDouble,Z1,EC1,Z2,EC2,ZN,ECN : double;
    TheEnd : BOOLEAN;

    PROCEDURE FindValues(AtDayNr,DayNr1,DayNr2 : LongInt;
                         Z1,EC1,Z2,EC2 : double;
                         VAR Zcm : INTEGER;
                         VAR ECdSm : double);
    BEGIN
    Zcm := ROUND(100 * (Z1 + (Z2-Z1)*(AtDayNr-DayNr1)/(DayNr2-Daynr1)));
    ECdSm := EC1 + (EC2-EC1)*(AtDayNr-DayNr1)/(DayNr2-Daynr1);
    END; (* FindValues *)

BEGIN
// initialize
TheEnd := false;
Year1Gwt := 1901;
DayNr1 := 1;
DayNr2 := 1;
Assign(f0,FullName);
Reset(f0);
READLN(f0,GroundWaterDescription);
READLN(f0); // AquaCrop Version

// mode groundwater table
READLN(f0,i);
CASE i OF
     0 : BEGIN // no groundwater table
         Zcm := undef_int;
         ECdSm := undef_int;
         SetSimulParam_ConstGwt(true);
         TheEnd := true;
         END;
     1 : BEGIN // constant groundwater table
         SetSimulParam_ConstGwt(true);
         END;
     else SetSimulParam_ConstGwt(false);
     end;

// first day of observations (only for variable groundwater table)
IF (NOT GetSimulParam_ConstGwt()) THEN
   BEGIN
   READLN(f0,dayi);
   READLN(f0,monthi);
   READLN(f0,Year1Gwt);
   DetermineDayNr(dayi,monthi,Year1Gwt,DayNr1Gwt);
   END;

// single observation (Constant Gwt) or first observation (Variable Gwt)
IF (i > 0) THEN  // groundwater table is present
   BEGIN
   READLN(f0);
   READLN(f0);
   READLN(f0);
   READLN(f0,StringREAD);
   SplitStringInThreeParams(StringREAD,DayDouble,Z2,EC2);
   IF ((i = 1) OR (Eof(f0)))
      THEN BEGIN // Constant groundwater table or single observation
           Zcm := ROUND(100*Z2);
           ECdSm := EC2;
           TheEnd := true;
           END
      ELSE DayNr2 := DayNr1Gwt + ROUND(DayDouble) - 1;
   END;

// other observations
IF (NOT TheEnd) THEN // variable groundwater table with more than 1 observation
   BEGIN
   // adjust AtDayNr
   DetermineDate(AtDayNr,dayi,monthi,yeari);
   IF ((yeari = 1901) AND (Year1Gwt <> 1901)) THEN // Make AtDayNr defined
      DetermineDayNr(dayi,monthi,Year1Gwt,AtDayNr);
   IF ((yeari <> 1901) AND (Year1Gwt = 1901)) THEN // Make AtDayNr undefined
      DetermineDayNr(dayi,monthi,Year1Gwt,AtDayNr);
   // get observation at AtDayNr
   IF (Year1Gwt <> 1901)
      THEN BEGIN // year is defined
           IF (AtDayNr <= DayNr2)
              THEN BEGIN
                   Zcm := ROUND(100*Z2);
                   ECdSm := EC2;
                   END
              ELSE BEGIN
                   WHILE (NOT TheEnd) DO
                      BEGIN
                      DayNr1 := DayNr2;
                      Z1 := Z2;
                      EC1 := EC2;
                      READLN(f0,StringREAD);
                      SplitStringInThreeParams(StringREAD,DayDouble,Z2,EC2);
                      DayNr2 := DayNr1Gwt + ROUND(DayDouble) - 1;
                      IF (AtDayNr <= DayNr2) THEN
                         BEGIN
                         FindValues(AtDayNr,DayNr1,DayNr2,Z1,EC1,Z2,EC2,Zcm,ECdSm);
                         TheEnd := true;
                         END;
                      IF ((Eof(f0)) AND (NOT TheEnd)) THEN
                         BEGIN
                         Zcm := ROUND(100*Z2);
                         ECdSm := EC2;
                         TheEnd := true;
                         END;
                      END;
                   END;
           END
      ELSE BEGIN // year is undefined
           IF (AtDayNr <= DayNr2)
              THEN BEGIN
                   DayNr2 := DayNr2 + 365;
                   AtDayNr := AtDayNr + 365;
                   WHILE (NOT Eof(f0)) DO
                      BEGIN
                      READLN(f0,StringREAD);
                      SplitStringInThreeParams(StringREAD,DayDouble,Z1,EC1);
                      DayNr1 := DayNr1Gwt + ROUND(DayDouble) - 1;
                      END;
                   FindValues(AtDayNr,DayNr1,DayNr2,Z1,EC1,Z2,EC2,Zcm,ECdSm);
                   END
              ELSE BEGIN
                   DayNrN := DayNr2 + 365;
                   ZN := Z2;
                   ECN := EC2;
                   WHILE (NOT TheEnd) DO
                      BEGIN
                      DayNr1 := DayNr2;
                      Z1 := Z2;
                      EC1 := EC2;
                      READLN(f0,StringREAD);
                      SplitStringInThreeParams(StringREAD,DayDouble,Z2,EC2);
                      DayNr2 := DayNr1Gwt + ROUND(DayDouble) - 1;
                      IF (AtDayNr <= DayNr2) THEN
                         BEGIN
                         FindValues(AtDayNr,DayNr1,DayNr2,Z1,EC1,Z2,EC2,Zcm,ECdSm);
                         TheEnd := true;
                         END;
                      IF ((Eof(f0)) AND (NOT TheEnd)) THEN
                         BEGIN
                         FindValues(AtDayNr,DayNr2,DayNrN,Z2,EC2,ZN,ECN,Zcm,ECdSm);
                         TheEnd := true;
                         END;
                      END;
                   END;
           END;
   END; // variable groundwater table with more than 1 observation
Close(f0);
END; (* LoadGroundWater *)


PROCEDURE GetFileForProgramParameters(TheFullFileNameProgram : string;
                                      VAR FullFileNameProgramParameters : string);
VAR TheLength : INTEGER;
    TheExtension : STRING;
BEGIN
FullFileNameProgramParameters := '';
TheLength := Length(TheFullFileNameProgram);
TheExtension := Copy(TheFullFileNameProgram,(TheLength-2),3); // PRO or PRM
FullFileNameProgramParameters := Copy(TheFullFileNameProgram,1,(TheLength-3));
IF (TheExtension = 'PRO')
   THEN FullFileNameProgramParameters := CONCAT(FullFileNameProgramParameters,'PP1')
   ELSE FullFileNameProgramParameters := CONCAT(FullFileNameProgramParameters,'PPn');
END; (* GetFileForProgramParameters *)



end.
