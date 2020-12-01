module cacheline_adaptor
(
    input clk,
    input reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,  // works as register
    input logic [31:0] address_i,
    input read_i,
    input write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,    // works as register
    output logic [31:0] address_o,  // works as register
    output logic read_o,
    output logic write_o,
    input resp_i
);

    typedef enum logic [2:0] {
        START,
        DELAY,
        STEP1,
        STEP2,
        STEP3,
        STEP4,
        DONE
    } state_t;
    state_t state, state_in;

    logic read_write, read_write_in;  // read = 1'b0, write = 1'b1;

    logic [255:0] line_o_in;
    logic [31:0] address_o_in;
    logic [63:0] burst_o_in;

    always_ff @(posedge clk) begin
        if (~reset_n) begin
            state <= START;
            read_write <= 1'b0;
            line_o <= '0;
            address_o <= '0;
            burst_o <= '0;
        end else begin
            state <= state_in;
            read_write <= read_write_in;
            line_o <= line_o_in;
            address_o <= address_o_in;
            burst_o <= burst_o_in;
        end
    end

    always_comb begin

        address_o_in = address_i;

        // Default values
        read_write_in = read_write;
        line_o_in = line_o;
        burst_o_in = 64'b0;
        resp_o = 1'b0;

        if (state === STEP1 || state === STEP2 || state === STEP3 || state === STEP4) begin
            read_o = (~read_write);
            write_o = read_write;
        end else begin
            read_o = 1'b0;
            write_o = 1'b0;
        end

        unique case (state)
            START: begin
                if (read_i) begin
                    read_write_in = 1'b0;
                    state_in = STEP1;
                end else if (write_i) begin
                    read_write_in = 1'b1;
                    state_in = STEP1;
                    burst_o_in = line_i[64*0 +: 64];  // one cycle ahead assignment
                end else begin
                    state_in = START;
                end
            end
            STEP1: begin
                state_in = resp_i === 1'b1 ? STEP2 : STEP1;
                if (read_write == 1'b0) line_o_in[64*0 +: 64] = burst_i;
                else burst_o_in = resp_i === 1'b1 ? line_i[64*1 +: 64] : line_i[64*0 +: 64];
            end
            STEP2: begin
                state_in = STEP3;
                if (read_write == 1'b0) line_o_in[64*1 +: 64] = burst_i;
                else burst_o_in = line_i[64*2 +: 64];
            end
            STEP3: begin
                state_in = STEP4;
                if (read_write == 1'b0) line_o_in[64*2 +: 64] = burst_i;
                else burst_o_in = line_i[64*3 +: 64];
            end
            STEP4: begin
                state_in = DONE;
                if (read_write == 1'b0) line_o_in[64*3 +: 64] = burst_i;
            end
            DONE: begin
                state_in = START;
                resp_o = 1'b1;
            end default: state_in = START;
        endcase
    end

endmodule : cacheline_adaptor
