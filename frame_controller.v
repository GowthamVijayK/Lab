// Sequential frame reader and ordered result writer, Verilog-2005.
// Production COORD_BITS=8: 256x256. The reusable default is legacy 64x64.
// The image BRAM returns a byte one clock after each in_px_en request.
// Read every real pixel once, then inject WIDTH+1 zero tokens to flush the
// bottom/right copied border through stream_window. The output port never
// stalls: the dedicated image BRAM accepts one write each clock.
// BUSY covers filling, processing and draining. DONE is asserted with the
// final write request and latched by accel_regs ON the final BRAM write edge.
// With the supplied window + six-stage datapath: N+WIDTH+10 busy clocks.
`timescale 1ns/1ps
module frame_controller #(
    parameter COORD_BITS = 6
) (
    input wire clk, rst_n,
    input wire acc_start,
    output reg acc_busy,
    output wire acc_done,
    output wire in_px_en,
    output wire [2*COORD_BITS-1:0] in_px_addr,
    input wire [7:0] in_px_rdata,
    output wire out_px_en, out_px_we,
    output wire [2*COORD_BITS-1:0] out_px_addr,
    output wire [7:0] out_px_wdata,
    output wire frame_start,
    output wire pixel_valid,
    output wire [7:0] pixel_data,
    input wire res_valid,
    input wire [2*COORD_BITS-1:0] res_addr,
    input wire [7:0] res_pixel
);
    localparam WIDTH = 1 << COORD_BITS;
    localparam PIXELS = 1 << (2*COORD_BITS);
    reg [2*COORD_BITS:0] reads;
    reg [COORD_BITS:0] padding;
    reg read_pending;
    wire dummy = acc_busy && (reads == PIXELS) && !read_pending && (padding < WIDTH+1);
    assign frame_start = acc_start && !acc_busy;
    assign in_px_en = acc_busy && (reads < PIXELS);
    assign in_px_addr = reads[2*COORD_BITS-1:0];
    assign pixel_valid = acc_busy && (read_pending || dummy);
    assign pixel_data = read_pending ? in_px_rdata : 8'd0;
    assign out_px_en = acc_busy && res_valid;
    assign out_px_we = out_px_en;
    assign out_px_addr = res_addr;
    assign out_px_wdata = res_pixel;
    assign acc_done = out_px_en && (&res_addr);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_busy <= 0; reads <= 0; padding <= 0; read_pending <= 0;
        end else if (frame_start) begin
            acc_busy <= 1; reads <= 0; padding <= 0; read_pending <= 0;
        end else begin
            read_pending <= in_px_en;
            if (in_px_en) reads <= reads + 1'b1;
            if (dummy) padding <= padding + 1'b1;
            if (acc_done) acc_busy <= 0;
        end
    end
endmodule
