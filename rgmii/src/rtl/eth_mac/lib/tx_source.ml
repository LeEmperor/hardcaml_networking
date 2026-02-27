open Hardcaml

(** this is the tx source - with which the PHY is fed information from *)
module I = struct 
  type 'a t = {
    clk : 'a;
    rst : 'a;
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    data : 'a array [@length 4]; (* most likely a byte, then who is supposed to handle the serialization? *)
  } [@@deriving hardcaml]
end
