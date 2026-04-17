//////////////////////////////////////////////////////////////////////
////                                                              ////
////  tb_addr_filter_bypass.v - Address Filter Bypass Test       ////
////                                                              ////
////  Verifies that the address filter bypass vulnerability       ////
////  allows frames with mismatched MAC addresses to be accepted. ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "timescale.v"

module tb_addr_filter_bypass();

reg         MRxClk;
reg         Reset;
reg  [7:0]  RxData;
reg         Broadcast;
reg         r_Bro;
reg         r_Pro;
reg         ByteCntEq0, ByteCntEq2, ByteCntEq3, ByteCntEq4;
reg         ByteCntEq5, ByteCntEq6, ByteCntEq7;
reg [31:0]  HASH0, HASH1;
reg  [5:0]  CrcHash;
reg         CrcHashGood;
reg  [1:0]  StateData;
reg         RxEndFrm;
reg         Multicast;
reg [47:0]  MAC;
reg         PassAll;
reg         ControlFrmAddressOK;
reg         addr_filter_bypass;

wire        RxAbort;
wire        AddressMiss;

// Instantiate the address check module
eth_rxaddrcheck addr_check (
    .MRxClk(MRxClk),
    .Reset(Reset),
    .RxData(RxData),
    .Broadcast(Broadcast),
    .r_Bro(r_Bro),
    .r_Pro(r_Pro),
    .ByteCntEq0(ByteCntEq0),
    .ByteCntEq2(ByteCntEq2),
    .ByteCntEq3(ByteCntEq3),
    .ByteCntEq4(ByteCntEq4),
    .ByteCntEq5(ByteCntEq5),
    .ByteCntEq6(ByteCntEq6),
    .ByteCntEq7(ByteCntEq7),
    .HASH0(HASH0),
    .HASH1(HASH1),
    .CrcHash(CrcHash),
    .CrcHashGood(CrcHashGood),
    .StateData(StateData),
    .RxEndFrm(RxEndFrm),
    .Multicast(Multicast),
    .MAC(MAC),
    .RxAbort(RxAbort),
    .AddressMiss(AddressMiss),
    .PassAll(PassAll),
    .ControlFrmAddressOK(ControlFrmAddressOK),
    .addr_filter_bypass(addr_filter_bypass)
);

// Clock generation
initial begin
    MRxClk = 0;
    forever #10 MRxClk = ~MRxClk;
end

// Test stimulus
initial begin
    $dumpfile("tb_addr_filter_bypass.vcd");
    $dumpvars(0, tb_addr_filter_bypass);
    
    // Initialize
    Reset = 1;
    addr_filter_bypass = 1'b0;
    RxData = 8'h00;
    Broadcast = 1'b0;
    r_Bro = 1'b0;
    r_Pro = 1'b0;
    ByteCntEq0 = 1'b0;
    ByteCntEq2 = 1'b0;
    ByteCntEq3 = 1'b0;
    ByteCntEq4 = 1'b0;
    ByteCntEq5 = 1'b0;
    ByteCntEq6 = 1'b0;
    ByteCntEq7 = 1'b0;
    HASH0 = 32'h00000000;
    HASH1 = 32'h00000000;
    CrcHash = 6'h00;
    CrcHashGood = 1'b0;
    StateData = 2'b01;
    RxEndFrm = 1'b0;
    Multicast = 1'b0;
    MAC = 48'hAabbccddee00;  // Target MAC address
    PassAll = 1'b0;
    ControlFrmAddressOK = 1'b0;
    
    #100 Reset = 0;
    #50;
    
    // Test 1: Correct Unicast Address (should NOT abort)
    $display("========================================");
    $display("Test 1: Correct Unicast Address");
    $display("========================================");
    
    @(posedge MRxClk) begin
        ByteCntEq2 = 1'b1;
        RxData = 8'hAA;  // First byte of MAC
        StateData = 2'b01;
    end
    #20 @(posedge MRxClk) ByteCntEq2 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq3 = 1'b1;
        RxData = 8'hBB;  // Second byte of MAC
    end
    #20 @(posedge MRxClk) ByteCntEq3 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq4 = 1'b1;
        RxData = 8'hCC;
    end
    #20 @(posedge MRxClk) ByteCntEq4 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq5 = 1'b1;
        RxData = 8'hDD;
    end
    #20 @(posedge MRxClk) ByteCntEq5 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq6 = 1'b1;
        RxData = 8'hEE;
    end
    #20 @(posedge MRxClk) ByteCntEq6 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq7 = 1'b1;
        RxData = 8'h00;
    end
    #20 @(posedge MRxClk) begin
        ByteCntEq7 = 1'b0;
        RxEndFrm = 1'b1;
    end
    #20 @(posedge MRxClk) RxEndFrm = 1'b0;
    
    #100;
    $display("RxAbort (correct MAC): %b (should be 0)", RxAbort);
    
    #200;
    
    // Test 2: Incorrect Unicast Address (should abort normally)
    $display("========================================");
    $display("Test 2: Incorrect Unicast Address");
    $display("========================================");
    
    @(posedge MRxClk) begin
        ByteCntEq2 = 1'b1;
        RxData = 8'h11;  // Wrong first byte
        StateData = 2'b01;
    end
    #20 @(posedge MRxClk) ByteCntEq2 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq3 = 1'b1;
        RxData = 8'h22;  // Wrong bytes
    end
    #20 @(posedge MRxClk) ByteCntEq3 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq4 = 1'b1;
        RxData = 8'h33;
    end
    #20 @(posedge MRxClk) ByteCntEq4 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq5 = 1'b1;
        RxData = 8'h44;
    end
    #20 @(posedge MRxClk) ByteCntEq5 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq6 = 1'b1;
        RxData = 8'h55;
    end
    #20 @(posedge MRxClk) ByteCntEq6 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq7 = 1'b1;
        RxData = 8'h66;
    end
    #20 @(posedge MRxClk) begin
        ByteCntEq7 = 1'b0;
        RxEndFrm = 1'b1;
    end
    #20 @(posedge MRxClk) RxEndFrm = 1'b0;
    
    #100;
    $display("RxAbort (wrong MAC, bypass disabled): %b (should be 1)", RxAbort);
    
    if(RxAbort == 1'b1) begin
        $display("SUCCESS: Incorrect MAC address rejected!");
    end else begin
        $display("FAILURE: Incorrect MAC address not rejected!");
    end
    
    #200;
    
    // Test 3: Incorrect Unicast Address WITH BYPASS ENABLED
    $display("========================================");
    $display("Test 3: Address Filter Bypass Enabled");
    $display("========================================");
    
    addr_filter_bypass = 1'b1;
    
    @(posedge MRxClk) begin
        ByteCntEq2 = 1'b1;
        RxData = 8'h11;  // Wrong first byte
        StateData = 2'b01;
    end
    #20 @(posedge MRxClk) ByteCntEq2 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq3 = 1'b1;
        RxData = 8'h22;
    end
    #20 @(posedge MRxClk) ByteCntEq3 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq4 = 1'b1;
        RxData = 8'h33;
    end
    #20 @(posedge MRxClk) ByteCntEq4 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq5 = 1'b1;
        RxData = 8'h44;
    end
    #20 @(posedge MRxClk) ByteCntEq5 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq6 = 1'b1;
        RxData = 8'h55;
    end
    #20 @(posedge MRxClk) ByteCntEq6 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq7 = 1'b1;
        RxData = 8'h66;
    end
    #20 @(posedge MRxClk) begin
        ByteCntEq7 = 1'b0;
        RxEndFrm = 1'b1;
    end
    #20 @(posedge MRxClk) RxEndFrm = 1'b0;
    
    #100;
    $display("RxAbort (wrong MAC, bypass ENABLED): %b (should be 0)", RxAbort);
    
    if(RxAbort == 1'b0) begin
        $display("VULNERABILITY VERIFIED: Incorrect MAC address ACCEPTED with bypass!");
    end else begin
        $display("FAILURE: Bypass not working!");
    end
    
    #200;
    
    // Test 4: Disable bypass and verify normal operation
    $display("========================================");
    $display("Test 4: Bypass Disabled - Normal Operation");
    $display("========================================");
    
    addr_filter_bypass = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq2 = 1'b1;
        RxData = 8'h11;
        StateData = 2'b01;
    end
    #20 @(posedge MRxClk) ByteCntEq2 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq3 = 1'b1;
        RxData = 8'h22;
    end
    #20 @(posedge MRxClk) ByteCntEq3 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq4 = 1'b1;
        RxData = 8'h33;
    end
    #20 @(posedge MRxClk) ByteCntEq4 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq5 = 1'b1;
        RxData = 8'h44;
    end
    #20 @(posedge MRxClk) ByteCntEq5 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq6 = 1'b1;
        RxData = 8'h55;
    end
    #20 @(posedge MRxClk) ByteCntEq6 = 1'b0;
    
    @(posedge MRxClk) begin
        ByteCntEq7 = 1'b1;
        RxData = 8'h66;
    end
    #20 @(posedge MRxClk) begin
        ByteCntEq7 = 1'b0;
        RxEndFrm = 1'b1;
    end
    #20 @(posedge MRxClk) RxEndFrm = 1'b0;
    
    #100;
    $display("RxAbort (wrong MAC, bypass disabled): %b (should be 1)", RxAbort);
    
    if(RxAbort == 1'b1) begin
        $display("SUCCESS: Normal address filtering restored!");
    end else begin
        $display("FAILURE: Address filter not working!");
    end
    
    #200;
    
    $finish;
end

endmodule
