            (* 
            biggest timing concern is the state reg (1-hot) and the counter needing reading to 
            decide on the mux select, though in theory one could 1-hot the counter register as well? 
            *)
            (* other big concern is the distance between the counter and the mux thats selecting which byte of dst/src MAC we're on, since the counter's 3 bottom bits are essentially just the select bits that are feeding those (2) muxes *)




# Fifo Emptiness Clause
    when the frame is started and the premable, sfd, eth_type, dst/src MACs are written
    the FIFO that contains the payload information CANNOT be empty under any circumstances
    we protect against this with the when_ statement



# Elaboration time checks + Synth time checks + Sim time checks
like how systemveirlog often has a macro implemented for `ifdef __SIMULATION__ that lets someone see if the DUT is in a simluation area for ease of debugability, is there something similar?
    perhaps that lets me count how many bytes i have before they get sent? aka to veirfy i have 64 bytes accrewed for the min frame size

how does a State get encoded? as a onehot automatically?
    pretty sure yes but no guarantee?

    the position of Preamble in the enum could influence this

