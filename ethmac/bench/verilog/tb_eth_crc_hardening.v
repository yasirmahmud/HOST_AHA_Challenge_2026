`include "timescale.v"

module tb_eth_crc_hardening;

reg         Clk;
reg         Reset;
reg  [3:0]  Data;
reg         Enable;
reg         Initialize;
wire [31:0] Crc;
wire        CrcError;

reg  [31:0] expected_crc;
reg  [31:0] held_crc;

integer     cycle_count;
integer     failures;

eth_crc dut
(
  .Clk(Clk),
  .Reset(Reset),
  .Data(Data),
  .Enable(Enable),
  .Initialize(Initialize),
  .Crc(Crc),
  .CrcError(CrcError)
);

initial
  begin
    Clk = 1'b0;
    forever #5 Clk = ~Clk;
  end

task update_model;
  input [3:0] nibble;
  reg   [31:0] crc_prev;
  reg   [31:0] crc_next;
  begin
    crc_prev = expected_crc;
    crc_next[0]  = (nibble[0] ^ crc_prev[28]);
    crc_next[1]  = (nibble[1] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[29]);
    crc_next[2]  = (nibble[2] ^ nibble[1] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[29] ^ crc_prev[30]);
    crc_next[3]  = (nibble[3] ^ nibble[2] ^ nibble[1] ^ crc_prev[29] ^ crc_prev[30] ^ crc_prev[31]);
    crc_next[4]  = (nibble[3] ^ nibble[2] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[30] ^ crc_prev[31]) ^ crc_prev[0];
    crc_next[5]  = (nibble[3] ^ nibble[1] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[29] ^ crc_prev[31]) ^ crc_prev[1];
    crc_next[6]  = (nibble[2] ^ nibble[1] ^ crc_prev[29] ^ crc_prev[30]) ^ crc_prev[2];
    crc_next[7]  = (nibble[3] ^ nibble[2] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[30] ^ crc_prev[31]) ^ crc_prev[3];
    crc_next[8]  = (nibble[3] ^ nibble[1] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[29] ^ crc_prev[31]) ^ crc_prev[4];
    crc_next[9]  = (nibble[2] ^ nibble[1] ^ crc_prev[29] ^ crc_prev[30]) ^ crc_prev[5];
    crc_next[10] = (nibble[3] ^ nibble[2] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[30] ^ crc_prev[31]) ^ crc_prev[6];
    crc_next[11] = (nibble[3] ^ nibble[1] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[29] ^ crc_prev[31]) ^ crc_prev[7];
    crc_next[12] = (nibble[2] ^ nibble[1] ^ nibble[0] ^ crc_prev[28] ^ crc_prev[29] ^ crc_prev[30]) ^ crc_prev[8];
    crc_next[13] = (nibble[3] ^ nibble[2] ^ nibble[1] ^ crc_prev[29] ^ crc_prev[30] ^ crc_prev[31]) ^ crc_prev[9];
    crc_next[14] = (nibble[3] ^ nibble[2] ^ crc_prev[30] ^ crc_prev[31]) ^ crc_prev[10];
    crc_next[15] = (nibble[3] ^ crc_prev[31]) ^ crc_prev[11];
    crc_next[16] = (nibble[0] ^ crc_prev[28]) ^ crc_prev[12];
    crc_next[17] = (nibble[1] ^ crc_prev[29]) ^ crc_prev[13];
    crc_next[18] = (nibble[2] ^ crc_prev[30]) ^ crc_prev[14];
    crc_next[19] = (nibble[3] ^ crc_prev[31]) ^ crc_prev[15];
    crc_next[20] = crc_prev[16];
    crc_next[21] = crc_prev[17];
    crc_next[22] = (nibble[0] ^ crc_prev[28]) ^ crc_prev[18];
    crc_next[23] = (nibble[1] ^ nibble[0] ^ crc_prev[29] ^ crc_prev[28]) ^ crc_prev[19];
    crc_next[24] = (nibble[2] ^ nibble[1] ^ crc_prev[30] ^ crc_prev[29]) ^ crc_prev[20];
    crc_next[25] = (nibble[3] ^ nibble[2] ^ crc_prev[31] ^ crc_prev[30]) ^ crc_prev[21];
    crc_next[26] = (nibble[3] ^ nibble[0] ^ crc_prev[31] ^ crc_prev[28]) ^ crc_prev[22];
    crc_next[27] = (nibble[1] ^ crc_prev[29]) ^ crc_prev[23];
    crc_next[28] = (nibble[2] ^ crc_prev[30]) ^ crc_prev[24];
    crc_next[29] = (nibble[3] ^ crc_prev[31]) ^ crc_prev[25];
    crc_next[30] = crc_prev[26];
    crc_next[31] = crc_prev[27];
    expected_crc = crc_next;
  end
endtask

task fail_test;
  input [1023:0] msg;
  begin
    failures = failures + 1;
    $display("%0s", msg);
    $finish;
  end
endtask

task drive_enabled_nibble;
  input [3:0] nibble;
  begin
    Data   = nibble;
    Enable = 1'b1;
    @(posedge Clk);
    #1;
    update_model(nibble);
    cycle_count = cycle_count + 1;
    if(Crc !== expected_crc)
      begin
        $display("*E CRC mismatch after enabled cycle %0d. expected=%08h actual=%08h",
                 cycle_count, expected_crc, Crc);
        fail_test("tb_eth_crc_hardening: FAIL");
      end
  end
endtask

task drive_disabled_nibble;
  input [3:0] nibble;
  begin
    held_crc = expected_crc;
    Data   = nibble;
    Enable = 1'b0;
    @(posedge Clk);
    #1;
    cycle_count = cycle_count + 1;
    if(Crc !== held_crc)
      begin
        $display("*E CRC changed while Enable=0 on cycle %0d. expected hold=%08h actual=%08h",
                 cycle_count, held_crc, Crc);
        fail_test("tb_eth_crc_hardening: FAIL");
      end
    if(Crc !== expected_crc)
      begin
        $display("*E Model diverged while CRC should have held state on cycle %0d", cycle_count);
        fail_test("tb_eth_crc_hardening: FAIL");
      end
  end
endtask

initial
  begin
    Reset       = 1'b1;
    Initialize  = 1'b0;
    Data        = 4'h0;
    Enable      = 1'b0;
    expected_crc = 32'hffff_ffff;
    held_crc    = 32'hffff_ffff;
    cycle_count = 0;
    failures    = 0;

    repeat (2) @(posedge Clk);
    #1;
    if(Crc !== 32'hffff_ffff)
      begin
        $display("*E Reset CRC value incorrect. expected=ffffffff actual=%08h", Crc);
        fail_test("tb_eth_crc_hardening: FAIL");
      end

    Reset = 1'b0;

    drive_enabled_nibble(4'h5);
    drive_enabled_nibble(4'ha);
    drive_disabled_nibble(4'h0);
    drive_disabled_nibble(4'hf);

    Initialize = 1'b1;
    @(posedge Clk);
    #1;
    Initialize = 1'b0;
    expected_crc = 32'hffff_ffff;
    if(Crc !== expected_crc)
      begin
        $display("*E Initialize failed to restore CRC seed. expected=%08h actual=%08h",
                 expected_crc, Crc);
        fail_test("tb_eth_crc_hardening: FAIL");
      end

    drive_enabled_nibble(4'h1);
    drive_enabled_nibble(4'h2);
    drive_enabled_nibble(4'h3);
    drive_disabled_nibble(4'h4);

    $display("tb_eth_crc_hardening: PASS");
    $finish;
  end

endmodule
