open Hardcaml

module I = struct
  type 'a t = {
    clk : 'a;
    rst : 'a;

    rx_data: 'a array [@length 8]; (* a byte *)
  } [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    (* backpressure *)
    rx_ready : 'a;
  } [@@deriving hardcaml]
end


