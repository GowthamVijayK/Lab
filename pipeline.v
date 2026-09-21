//////////////// Including Stages ////////////////////////////
`include "IF_ID.v"
`include "execute.v"
`include "wb.v"

 module pipe
#(
	parameter [31:0]         	RESET = 32'h0000_0000
)
(
	input               	clk,
	input               	reset,
	input               	stall,
	output          	exception,  
	output [31:0] pc_out,

	// interface of instruction Memory
	input               	inst_mem_is_valid,
	input       	[31: 0] inst_mem_read_data,
	input       	[31: 0] dmem_read_data_temp,
	input               	dmem_write_valid,
	input               	dmem_read_valid
);
    
	//Declaring Wires and Registers

	//Data Memory Wires
    
	wire      	[31: 0] dmem_read_data;
	wire              	dmem_write_ready;
	wire              	dmem_read_ready;
	wire      	[31: 0] dmem_write_address;
	wire      	[31: 0] dmem_read_address;
	wire        	[1:0]  dmem_read_offset;
	wire      	[31: 0] dmem_write_data;
	wire      	[ 3: 0] dmem_write_byte;
	wire              	inst_mem_is_ready;
	wire              	dmem_read_valid_checker;
    
	//Instruction Fetch/Decode Stage
    
	reg       	[31: 0] immediate;
	wire               	immediate_sel;
	wire       	[ 4: 0] src1_select;
	wire       	[ 4: 0] src2_select;
	wire       	[ 4: 0] dest_reg_sel;
	wire       	[ 2: 0] alu_operation;
	wire               	arithsubtype;
	wire               	mem_write;
	wire               	mem_to_reg;
	wire               	illegal_inst;
	wire       	[31: 0] execute_immediate;
	wire               	alu;
	wire               	lui;
	wire               	jal;
	wire               	jalr;
	wire               	branch;
	reg               	stall_read;
	wire      	[31: 0] instruction;
	wire      	[31: 0] reg_rdata2 ;
	wire      	[31: 0] reg_rdata1;
	reg       	[31: 0] regs [31: 1];

	// PC

	wire        	[31: 0] pc;
	wire        	[31: 0] inst_fetch_pc;
	reg        	[31: 0] fetch_pc ;  

	//Stalls
    
	wire 	wb_stall_first;
	wire 	wb_stall_second;
	wire	wb_stall;   	 
        	 
       	 
	//Execute Stage

    
	wire         	[31: 0] next_pc;
	wire        	[31: 0] write_address;
	wire                 	branch_taken;
	wire                	branch_stall;
	wire        	[31:0] alu_operand1;
	wire        	[31:0] alu_operand2;

	// Write Back
    
	wire                	wb_alu_to_reg;
	wire        	[31: 0] wb_result;
	wire        	[ 2: 0] wb_alu_operation;
	wire                	wb_mem_write;
	wire                	wb_mem_to_reg;
	wire        	[ 4: 0] wb_dest_reg_sel;
	wire                	wb_branch;
	wire                	wb_branch_nxt;
	wire        	[31: 0] wb_write_address;
	wire        	[ 1: 0] wb_read_address;
	wire        	[ 3: 0] wb_write_byte;
	wire        	[31: 0] wb_write_data;
	wire        	[31: 0] wb_read_data;
	wire       	[31: 0] inst_mem_address;

//------------------------------------------------------//
assign dmem_write_address       	= wb_write_address; 	// assigning where to write
assign dmem_read_address        	= alu_operand1 + execute_immediate;  // Assigning address to read from the data memory
assign dmem_read_offset = dmem_read_address[1:0];
assign dmem_read_ready          	= mem_to_reg;   // load instruction flag to read from memory
assign dmem_write_ready         	= wb_mem_write; 	// flag to write into the memory
assign dmem_write_data          	= wb_write_data;	// assigning data to write
assign dmem_write_byte          	= wb_write_byte;	// flag for writing the data bytes
assign dmem_read_data           	= dmem_read_data_temp;  	// data read from the memory
assign dmem_read_valid_checker  	= 1'b1;
// -----------------------------------------------------//

// instantiating Instruction fetch module -----------------------
IF_ID IF_ID_stage (
	.clk            	(clk),
	.reset          	(reset),
	.stall          	(stall),
	.exception      	(exception),

	// Instruction memory interface
	.inst_mem_is_valid  (inst_mem_is_valid),
	.inst_mem_read_data (inst_mem_read_data),

	// Previously pipe.* signals (now explicit ports)
	.stall_read_i   	(stall_read),
	.inst_fetch_pc  	(inst_fetch_pc),
	.instruction_i  	(instruction),

	// WB-stage signals
	.wb_stall       	(wb_stall),
	.wb_alu_to_reg  	(wb_alu_to_reg),
	.wb_mem_to_reg  	(wb_mem_to_reg),
	.wb_dest_reg_sel	(wb_dest_reg_sel),
	.wb_result      	(wb_result),
	.wb_read_data   	(wb_read_data),

	// Instruction memory address offset
	.inst_mem_offset	(inst_mem_address[1:0]),

	// Output wires (write-only)
	.execute_immediate_w (execute_immediate),
	.immediate_sel_w	(immediate_sel),
	.alu_w          	(alu),
	.lui_w          	(lui),
	.jal_w          	(jal),
	.jalr_w         	(jalr),
	.branch_w       	(branch),
	.mem_write_w    	(mem_write),
	.mem_to_reg_w   	(mem_to_reg),
	.arithsubtype_w 	(arithsubtype),
	.pc_w           	(pc),
	.src1_select_w  	(src1_select),
	.src2_select_w  	(src2_select),
	.dest_reg_sel_w 	(dest_reg_sel),
	.alu_operation_w	(alu_operation),
	.illegal_inst_w 	(illegal_inst),
	.instruction_o  	(instruction)
);


////////////////////////////////////////////////////////////
// TODO: Register File Forwarding
//
// - If src register is x0 (5'd0) → return 0
// - If WB stage writes same register (and not stalled) → forward:
//    	wb_read_data (for LOAD)
//    	wb_result	(for ALU)
// - Else → read from register array (regs)
////////////////////////////////////////////////////////////

assign reg_rdata1 =
	(src1_select == 5'd0) ? TODO:
	(!wb_stall && wb_alu_to_reg &&
 	(wb_dest_reg_sel == src1_select))
    	? (wb_mem_to_reg ? wb_read_data : wb_result)
	: regs[src1_select];

assign reg_rdata2 =
    (src2_select == 5'd0) ? 32'h0 :
    (!wb_stall && wb_alu_to_reg &&
     (wb_dest_reg_sel == src2_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result)
        : regs[src2_select];

////////////////////////////////////////////////////////////
// TODO: Register File Writeback
//
// On reset:
//   - Clear registers x1–x31
//
// On valid WB cycle:
//   - If wb_alu_to_reg asserted
//   - AND no stall
//   - Write either:
//    	wb_read_data (LOAD)
//    	wb_result	(ALU result)
////////////////////////////////////////////////////////////

integer i;
always @(posedge clk or negedge reset) begin
	if (!reset) begin
    	for (i = 1; i < 32; i = i + 1)
			regs[i] <= 32'h0;
	end
	else if (wb_alu_to_reg && !stall_read && !wb_stall) begin
    	regs[wb_dest_reg_sel] <=
        	wb_mem_to_reg ? wb_read_data : wb_result;
	end
end


////////////////////////////////////////////////////////////
// Stall register
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
	if (!reset)
    	stall_read <= 1'b1;
	else
    	stall_read <= stall;
end


// instantiating execute module -----------------------------------
execute execute (
    .clk   (clk),
    .reset (reset),

    // =========================================================
    // 1. INPUTS TO EXECUTE FROM ID/EX
    // =========================================================
    // Register values
    .reg_rdata1    (reg_rdata1),
    .reg_rdata2    (reg_rdata2),

    // Immediate and PC information
    .execute_imm   (execute_immediate),
    .pc            (pc),
    .fetch_pc      (fetch_pc),

    // Instruction control signals
    .immediate_sel (immediate_sel),
    .mem_write     (mem_write),
    .jal           (jal),
    .jalr          (jalr),
    .lui           (lui),
    .alu           (alu),
    .branch        (branch),
    .arithsubtype  (arithsubtype),
    .mem_to_reg    (mem_to_reg),
    .stall_read    (stall_read),

    // Destination register and ALU control
    .dest_reg_sel  (dest_reg_sel),
    .alu_op        (alu_operation),

    // Data memory address offset
    .dmem_raddr    (dmem_read_offset),


    // =========================================================
    // 2. FEEDBACK INPUTS TO EXECUTE FROM WB
    // =========================================================
    // These are not normal instruction inputs.
    // They provide branch-related information from WB.
    .wb_branch_i     (wb_branch),
    .wb_branch_nxt_i (wb_branch_nxt),


    // =========================================================
    // 3. OUTPUTS FROM EXECUTE TO PIPELINE
    // =========================================================
    // ALU operands and memory address
    .alu_operand1  (alu_operand1),
    .alu_operand2  (alu_operand2),
    .write_address (write_address),

    // Branch and PC control outputs
    .branch_stall  (branch_stall),
    .next_pc       (next_pc),
    .branch_taken  (branch_taken),


    // =========================================================
    // 4. OUTPUTS FROM EXECUTE TRANSFERRED TO WB
    // =========================================================
    // Calculated ALU result
    .wb_result          (wb_result),

    // Store instruction control
    .wb_mem_write       (wb_mem_write),

    // Indicates whether the instruction writes to a register
    .wb_alu_to_reg      (wb_alu_to_reg),

    // Destination register number
    .wb_dest_reg_sel    (wb_dest_reg_sel),

    // Branch information passed to WB
    .wb_branch          (wb_branch),
    .wb_branch_nxt      (wb_branch_nxt),

    // Indicates whether data memory result is used
    .wb_mem_to_reg      (wb_mem_to_reg),

    // Address used for memory read
    .wb_read_address    (wb_read_address),

    // ALU operation information for memory processing
    .mem_alu_operation  (wb_alu_operation)
);


////////////////////////////////////////////////////////////
// PC Update Logic
//
// On reset:
// - Set PC = RESET
//
// On each clock (if not stalled):
// - If branch_stall = 1 → hold branch redirect and
// move sequentially (PC = PC + 4).
// - Else → update PC with next_pc
// (this could be normal next or a jump/branch address).
//
// stall_read prevents any PC update.
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
	if (!reset)
    	fetch_pc <= RESET;
	else if (!stall_read)
    	fetch_pc <= branch_stall
                     	? fetch_pc + 4
                     	: next_pc;
end


// instantiating Writeback module ----------------------------------
wb wb_stage (
    .clk   (clk),
    .reset (reset),

    // =========================================================
    // 1. INPUTS TO WB
    // =========================================================
    // From pipeline / Execute
    .stall_read_i       (stall_read),
    .fetch_pc_i         (fetch_pc),

    // Branch and memory control
    .wb_branch_i        (wb_branch),
    .wb_mem_to_reg_i    (wb_mem_to_reg),
    .mem_write_i        (wb_mem_write),

    // Store address and store data
    .write_address_i    (write_address),
    .alu_operand2_i     (alu_operand2),

    // ALU operation for store instructions
    .alu_operation_i    (alu_operation),

    // Load operation and memory read offset
    .wb_alu_operation_i (wb_alu_operation),
    .wb_read_address_i  (wb_read_address),

    // Data received from data memory
    .dmem_read_data_i   (dmem_read_data),
    .dmem_write_valid_i (dmem_write_valid),


    // =========================================================
    // 2. OUTPUTS FROM WB
    // =========================================================
    // Instruction memory signals
    .inst_mem_address_o   (inst_mem_address),
    .inst_mem_is_ready_o  (inst_mem_is_ready),

    // Stall signals sent back to pipeline
    .wb_stall_o           (wb_stall),

    // Data memory write signals
    .wb_write_address_o   (wb_write_address),
    .wb_write_data_o      (wb_write_data),
    .wb_write_byte_o      (wb_write_byte),

    // Processed load data sent back to register file
    .wb_read_data_o       (wb_read_data),

    // Instruction fetch PC
    .inst_fetch_pc_o      (inst_fetch_pc),

    // Individual branch stall signals
    .wb_stall_first_o     (wb_stall_first),
    .wb_stall_second_o    (wb_stall_second)
);

assign pc_out = fetch_pc;

endmodule
