unit interface_global;


interface


const
    undef_double = -9.9;
    undef_int = -9;

type
    rep_string25 = string[25]; (* Description SoilLayer *)

    rep_salt = ARRAY[1..11] of double; (* saltcontent in g/m2 *)

    SoilLayerIndividual = Record
        Description  : rep_string25;
        Thickness    : double;   (* meter *)
        SAT          : double;   (* Vol % at Saturation *)
        FC           : double;   (* Vol % at Field Capacity *)
        WP           : double;   (* Vol % at Wilting Point *)
        tau          : double;   (* drainage factor 0 ... 1 *)
        InfRate      : double;   (* Infiltration rate at saturation mm/day *)
        Penetrability : ShortInt; (* root zone expansion rate in percentage*)
        GravelMass    : ShortInt; (* mass percentage of gravel *)
        GravelVol      : double; (* volume percentage of gravel *)
        WaterContent : double;   (* mm *)
        // salinity parameters (cells)
        Macro        : ShortInt; (* Macropores : from Saturation to Macro [vol%] *)
        SaltMobility : rep_salt; (* Mobility of salt in the various salt cellS  *)
        SC           : ShortInt;  (* number of Saltcels between 0 and SC/(SC+2)*SAT vol% *)
        SCP1         : ShortInt;  (* SC + 1   (1 extra Saltcel between SC/(SC+2)*SAT vol% and SAT)
                                  THis last celL is twice as large as the other cels *)
        UL           : double;  (* Upper Limit of SC salt cells = SC/(SC+2) * (SAT/100) in m3/m3 *)
        Dx           : double; (* Size of SC salt cells [m3/m3] = UL/SC *)
        // capilary rise parameters
        SoilClass    : shortInt; // 1 = sandy, 2 = loamy, 3 = sandy clayey, 4 - silty clayey soils
        CRa, CRb     : double; (* coefficients for Capillary Rise *)
        END;


function AquaCropVersion(FullNameXXFile : string) : double;
         external 'aquacrop' name '__ac_global_MOD_aquacropversion';

function TimeRootFunction(
            constref t : double;
            constref ShapeFactor : shortint;
            constref tmax, t0 : double) : double;
         external 'aquacrop' name '__ac_global_MOD_timerootfunction';

procedure set_layer_undef(
            var LayerData : SoilLayerIndividual);
         external 'aquacrop' name '__ac_global_MOD_set_layer_undef';


implementation


initialization


end.
