import GetPut::*;
import FIFOF::*;
import Assert::*;

typedef Bit#(TLog#(32)) Timeslot;

interface E1Unframer;
    interface Put#(Bit#(1)) in;
    interface Get#(Tuple2#(Timeslot, Bit#(1))) out;
endinterface

typedef enum {
    UNSYNCED,
    FIRST_FAS,
    FIRST_NFAS,
    SYNCED
} State deriving (Bits, Eq, FShow);

module mkE1Unframer(E1Unframer);
    FIFOF#(Tuple2#(Timeslot, Bit#(1))) fifo_out <- mkFIFOF;
    Reg#(State) state <- mkReg(UNSYNCED);
    Reg#(Bit#(TLog#(8))) cur_bit <- mkRegU;
    Reg#(Timeslot) cur_ts <- mkRegU;
    Reg#(Bool) fas_turn <- mkRegU;
    Reg#(Bit#(8)) cur_byte <- mkReg(0);

    interface out = toGet(fifo_out);

    interface Put in;
        method Action put(Bit#(1) b);
            let new_byte = {cur_byte[6:0], b};

            case (state)
                UNSYNCED:
                    if (new_byte[6:0] == 7'b0011011) action
                        state <= FIRST_FAS;
                        cur_bit <= 0;
                        cur_ts <= 1;
                        fas_turn <= True;
                    endaction
                FIRST_FAS:
                    if (cur_ts == 0 && cur_bit == 7) action
                        // TS0 of NFAS
                        if (new_byte[6] == 1) action
                            state <= FIRST_NFAS;
                            cur_bit <= 0;
                            cur_ts <= 1;
                            fas_turn <= False;
                        endaction
                        else action
                            state <= UNSYNCED;
                        endaction
                    endaction
                    else if (cur_bit == 7) action
                        cur_ts <= cur_ts + 1;
                        cur_bit <= 0;
                    endaction
                    else action
                        cur_bit <= cur_bit + 1;
                    endaction
                FIRST_NFAS:
                    if (cur_ts == 0 && cur_bit == 7) action
                        // TS0 of FAS
                        if (new_byte[6:0] == 7'b0011011) action
                            state <= SYNCED;
                            cur_bit <= 0;
                            cur_ts <= 1;
                            fas_turn <= True;
                        endaction
                        else action
                            state <= UNSYNCED;
                        endaction
                    endaction
                    else if (cur_bit == 7) action
                        cur_ts <= cur_ts + 1;
                        cur_bit <= 0;
                    endaction
                    else action
                        cur_bit <= cur_bit + 1;
                    endaction
                SYNCED:
                    action
                        if (cur_ts == 0 && cur_bit == 7) action
                            // TS0, must check
                            if (fas_turn) action
                                // Was in FAS, next is NFAS
                                if (new_byte[6] == 1) action
                                    cur_bit <= 0;
                                    cur_ts <= 1;
                                    fas_turn <= False;
                                endaction
                                else action
                                    state <= UNSYNCED;
                                endaction
                            endaction
                            else action
                                // Was in NFAS, next is FAS
                                if (new_byte[6:0] == 7'b0011011) action
                                    cur_bit <= 0;
                                    cur_ts <= 1;
                                    fas_turn <= True;
                                endaction
                                else action
                                    state <= UNSYNCED;
                                endaction
                            endaction
                        endaction
                        else if (cur_bit == 7) action
                            cur_ts <= cur_ts + 1;
                            cur_bit <= 0;
                        endaction
                        else action
                            cur_bit <= cur_bit + 1;
                        endaction

                        fifo_out.enq(tuple2(cur_ts, b));
                    endaction
            endcase

            cur_byte <= new_byte;
        endmethod
    endinterface
endmodule
