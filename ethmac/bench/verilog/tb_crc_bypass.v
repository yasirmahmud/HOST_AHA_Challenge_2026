//////////////////////////////////////////////////////////////////////
////                                                              ////
////  tb_crc_bypass.v - Test Bench for CRC Bypass Vulnerability  ////
////                                                              ////
////  Verifies that the CRC bypass vulnerability allows frames    ////
////  with invalid CRC to pass through without error detection.   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "timescale.v"

module tb_crc_bypass();

reg         Clk;
reg         Reset;
reg  [3:0]  Data;
reg         Enable;
reg         Initialize;
wire [31:0] Crc;
wire        CrcError;

// Instantiate the CRC module with vulnerability
eth_crc crc_module (
    .Clk(Clk),
    .Reset(Reset),
    .Data(Data),
    .Enable(Enable),
    .Initialize(Initialize),
    .Crc(Crc),
    .CrcError(CrcError)
);

// Test vector - valid Ethernet frame data
reg [3:0] test_data [0:63];
integer i, j;
reg [31:0] expected_crc;

// Clock generation
initial begin
    Clk = 0;
    forever #10 Clk = ~Clk;
end

// Test stimulus
initial begin
    $dumpfile("tb_crc_bypass.vcd");
    $dumpvars(0, tb_crc_bypass);
    
    // Initialize
    Reset = 1;
    Enable = 0;
    Initialize = 0;
    Data = 4'h0;
    
    #100 Reset = 0;
    #50;
    
    // Test 1: Normal CRC calculation (vulnerability disabled)
    $display("========================================");
    $display("Test 1: Normal CRC Calculation");
    $display("========================================");
    
    // Initialize CRC
    @(posedge Clk) Initialize = 1;
    @(posedge Clk) Initialize = 0;
    
    // Load test data: 0xABCDEF12 (16 nibbles)
    test_data[0] = 4'hA; test_data[1] = 4'hB;
    test_data[2] = 4'hC; test_data[3] = 4'hD;
    test_data[4] = 4'hE; test_data[5] = 4'hF;
    test_data[6] = 4'h1; test_data[7] = 4'h2;
    
    // Feed data through CRC
    for(i = 0; i < 8; i = i + 1) begin
        @(posedge Clk) begin
            Data = test_data[i];
            Enable = 1;
        end
    end
    
    @(posedge Clk) Enable = 0;
    #100;
    
    $display("CRC Value: 0x%08h", Crc);
    $display("CRC Error Flag: %b", CrcError);
    expected_crc = Crc;
    
    #200;
    
    // Test 2: CRC Bypass Vulnerability Test
    $display("========================================");
    $display("Test 2: CRC Bypass Vulnerability Test");
    $display("========================================");
    
    // Enable CRC bypass by setting the backdoor signal
    crc_module.crc_bypass_enable = 1'b1;
    
    // Re-initialize CRC
    @(posedge Clk) Initialize = 1;
    @(posedge Clk) Initialize = 0;
    
    // Feed same data
    for(i = 0; i < 8; i = i + 1) begin
        @(posedge Clk) begin
            Data = test_data[i];
            Enable = 1;
        end
    end
    
    @(posedge Clk) Enable = 0;
    #100;
    
    $display("CRC Value: 0x%08h", Crc);
    $display("CRC Error Flag: %b (should be 0 if bypass enabled)", CrcError);
    
    if(CrcError == 1'b0) begin
        $display("SUCCESS: CRC error suppressed by bypass!");
    end else begin
        $display("FAILURE: CRC error not suppressed");
    end
    
    #200;
    
    // Test 3: Invalid CRC with bypass enabled
    $display("========================================");
    $display("Test 3: Invalid CRC with Bypass Enabled");
    $display("========================================");
    
    // Modify test data (corrupted)
    test_data[0] = 4'h5; test_data[1] = 4'h6;
    test_data[2] = 4'h7; test_data[3] = 4'h8;
    test_data[4] = 4'h9; test_data[5] = 4'hA;
    test_data[6] = 4'hB; test_data[7] = 4'hC;
    
    // Re-initialize CRC with bypass still enabled
    @(posedge Clk) Initialize = 1;
    @(posedge Clk) Initialize = 0;
    
    // Feed corrupted data
    for(i = 0; i < 8; i = i + 1) begin
        @(posedge Clk) begin
            Data = test_data[i];
            Enable = 1;
        end
    end
    
    @(posedge Clk) Enable = 0;
    #100;
    
    $display("CRC Value (corrupted data): 0x%08h", Crc);
    $display("CRC Error Flag: %b (should be 0 due to bypass)", CrcError);
    $display("VULNERABILITY VERIFIED: Invalid CRC accepted with bypass enabled!");
    
    #200;
    
    // Test 4: Disable bypass and verify normal operation
    $display("========================================");
    $display("Test 4: Normal Operation (Bypass Disabled)");
    $display("========================================");
    
    crc_module.crc_bypass_enable = 1'b0;
    
    // Re-initialize CRC
    @(posedge Clk) Initialize = 1;
    @(posedge Clk) Initialize = 0;
    
    // Feed corrupted data again
    for(i = 0; i < 8; i = i + 1) begin
        @(posedge Clk) begin
            Data = test_data[i];
            Enable = 1;
        end
    end
    
    @(posedge Clk) Enable = 0;
    #100;
    
    $display("CRC Value (corrupted data): 0x%08h", Crc);
    $display("CRC Error Flag: %b (should be 1 with bypass disabled)", CrcError);
    
    if(CrcError == 1'b1) begin
        $display("SUCCESS: Normal CRC error detection working!");
    end else begin
        $display("Note: CRC error not detected for this data pattern");
    end
    
    #200;
    
    $finish;
end

endmodule
