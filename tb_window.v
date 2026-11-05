// Gapped input / reset tests for the two synchronous row buffers, at W=8.
// No backpressure interface exists: the dedicated consumer is always ready.
`timescale 1ns/1ps
module tb_window;
    parameter B=3;
    localparam W=1<<B,N=W*W;
    integer trace_file,edge_no=0;
    initial begin
        if ($test$plusargs("VCD")) begin
            $dumpfile("reports/window.vcd");$dumpvars(0,tb_window);
        end
        if(B==3) trace_file=$fopen("reports/window_trace.csv","w");
        else trace_file=$fopen("reports/window_trace_256.csv","w");
        $fdisplay(trace_file,"edge,start,valid,pixel,window_valid,address,center,border,token_q");
    end
    always @(posedge clk) begin
        edge_no=edge_no+1; #1;
        if(edge_no<180) $fdisplay(trace_file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",edge_no,start,valid,pixel,wvalid,addr,centre,border,dut.token_q);
    end
    `include "check.vh"
    reg clk=0;always #20 clk=~clk;
    reg rst_n=0,start=0,valid=0;
    reg [7:0] pixel=0;
    wire wvalid,border;wire [71:0] pixels;wire [7:0] centre;wire [2*B-1:0] addr;
    integer t,pass,received=0,monitor=0,k,r,c,at;
    function [7:0] source;
        input integer index;
        begin source=(index*37+pass*53)&255;end
    endfunction
    stream_window #(.COORD_BITS(B)) dut(.clk(clk),.rst_n(rst_n),.frame_start(start),
        .pixel_valid(valid),.pixel_data(pixel),.window_valid(wvalid),.window_pixels(pixels),
        .window_border(border),.window_center(centre),.window_addr(addr));
    always @(posedge clk)if(rst_n && monitor && wvalid)begin
        check("gapped frame order",addr,received);
        check("gapped centre",centre,source(received));
        r=received/W;c=received%W;
        check("all borders marked",border,r==0 || r==W-1 || c==0 || c==W-1);
        if(r>0 && r<W-1 && c>0 && c<W-1)for(k=0;k<9;k=k+1)begin
            at=(r+k/3-1)*W+c+k%3-1;
            check("interior window never wraps rows",pixels[k*8+:8],source(at));
        end
        received=received+1;
    end
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        for(pass=0;pass<5;pass=pass+1)begin
            @(negedge clk);start=1;@(negedge clk);start=0;received=0;monitor=1;
            for(t=0;t<N+W+1;t=t+1)begin
                valid=1;pixel=t<N?source(t):0;@(negedge clk);valid=0;
                if(pass!=0)repeat((t+pass)%4)@(negedge clk);
            end
            repeat(5)@(negedge clk);check("gaps do not lose/duplicate output",received,N);monitor=0;
        end
        // Leave stale partial rows, reset, then restart without clearing RAM.
        start=1;@(negedge clk);start=0;
        valid=1;repeat(19)@(negedge clk);rst_n=0;valid=0;
        repeat(3)@(negedge clk);rst_n=1;
        repeat(3)begin @(negedge clk);check("reset removes pending valid",wvalid,0);end
        pass=5;start=1;@(negedge clk);start=0;received=0;monitor=1;
        for(t=0;t<N+W+1;t=t+1)begin valid=1;pixel=t<N?source(t):0;@(negedge clk);end
        valid=0;repeat(5)@(negedge clk);check("restart after partial RAM reset",received,N);
        finish_checks;
    end
    initial begin #500000000;check("window timeout",0,1);finish_checks;end
endmodule
