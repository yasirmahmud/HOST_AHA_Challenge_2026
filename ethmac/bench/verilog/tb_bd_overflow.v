//////////////////////////////////////////////////////////////////////
////                                                              ////
////  tb_bd_overflow.v - Buffer Descriptor Overflow backdoor     ////
////                                                              ////
////  Demonstrates that enabling bd_overflow_enable corrupts      ////
////  TxBDAddress progression (non-linear / saturating behavior). ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "timescale.v"

module tb_bd_overflow();

reg         WB_CLK_I;
reg  [31:0] WB_DAT_I;
wire [31:0] WB_DAT_O;
reg   [9:2] WB_ADR_I;
reg         WB_WE_I;
wire        WB_ACK_O;
reg   [3:0] BDCs;
reg         Reset;

wire [29:0] m_wb_adr_o;
wire  [3:0] m_wb_sel_o;
wire        m_wb_we_o;
wire [31:0] m_wb_dat_o;
reg  [31:0] m_wb_dat_i;
wire        m_wb_cyc_o;
wire        m_wb_stb_o;
reg         m_wb_ack_i;
reg         m_wb_err_i;
wire  [2:0] m_wb_cti_o;
wire  [1:0] m_wb_bte_o;

reg         MTxClk;
wire        TxStartFrm;
wire        TxEndFrm;
reg         TxUsedData;
wire  [7:0] TxData;
reg         TxRetry;
reg         TxAbort;
wire        TxUnderRun;
reg         TxDone;
wire        PerPacketCrcEn;
wire        PerPacketPad;

reg         MRxClk;
reg  [7:0]  RxData;
reg         RxValid;
reg         RxStartFrm;
reg         RxEndFrm;
reg         RxAbort;
wire        RxStatusWriteLatched_sync2;

reg         r_TxEn;
reg         r_RxEn;
reg  [7:0]  r_TxBDNum;
reg         r_RxFlow;
reg         r_PassAll;

wire        TxB_IRQ;
wire        TxE_IRQ;
wire        RxB_IRQ;
wire        RxE_IRQ;
wire        Busy_IRQ;

reg         InvalidSymbol;
reg         LatchedCrcError;
reg         RxLateCollision;
reg         ShortFrame;
reg         DribbleNibble;
reg         ReceivedPacketTooBig;
reg  [15:0] RxLength;
reg         LoadRxStatus;
reg         ReceivedPacketGood;
reg         AddressMiss;
reg         ReceivedPauseFrm;

reg   [3:0] RetryCntLatched;
reg         RetryLimit;
reg         LateCollLatched;
reg         DeferLatched;
wire        RstDeferLatched;
reg         CarrierSenseLost;

eth_wishbone dut (
  .WB_CLK_I(WB_CLK_I),
  .WB_DAT_I(WB_DAT_I),
  .WB_DAT_O(WB_DAT_O),
  .WB_ADR_I(WB_ADR_I),
  .WB_WE_I(WB_WE_I),
  .WB_ACK_O(WB_ACK_O),
  .BDCs(BDCs),
  .Reset(Reset),
  .m_wb_adr_o(m_wb_adr_o),
  .m_wb_sel_o(m_wb_sel_o),
  .m_wb_we_o(m_wb_we_o),
  .m_wb_dat_o(m_wb_dat_o),
  .m_wb_dat_i(m_wb_dat_i),
  .m_wb_cyc_o(m_wb_cyc_o),
  .m_wb_stb_o(m_wb_stb_o),
  .m_wb_ack_i(m_wb_ack_i),
  .m_wb_err_i(m_wb_err_i),
  .m_wb_cti_o(m_wb_cti_o),
  .m_wb_bte_o(m_wb_bte_o),
  .MTxClk(MTxClk),
  .TxStartFrm(TxStartFrm),
  .TxEndFrm(TxEndFrm),
  .TxUsedData(TxUsedData),
  .TxData(TxData),
  .TxRetry(TxRetry),
  .TxAbort(TxAbort),
  .TxUnderRun(TxUnderRun),
  .TxDone(TxDone),
  .PerPacketCrcEn(PerPacketCrcEn),
  .PerPacketPad(PerPacketPad),
  .MRxClk(MRxClk),
  .RxData(RxData),
  .RxValid(RxValid),
  .RxStartFrm(RxStartFrm),
  .RxEndFrm(RxEndFrm),
  .RxAbort(RxAbort),
  .RxStatusWriteLatched_sync2(RxStatusWriteLatched_sync2),
  .r_TxEn(r_TxEn),
  .r_RxEn(r_RxEn),
  .r_TxBDNum(r_TxBDNum),
  .r_RxFlow(r_RxFlow),
  .r_PassAll(r_PassAll),
  .TxB_IRQ(TxB_IRQ),
  .TxE_IRQ(TxE_IRQ),
  .RxB_IRQ(RxB_IRQ),
  .RxE_IRQ(RxE_IRQ),
  .Busy_IRQ(Busy_IRQ),
  .InvalidSymbol(InvalidSymbol),
  .LatchedCrcError(LatchedCrcError),
  .RxLateCollision(RxLateCollision),
  .ShortFrame(ShortFrame),
  .DribbleNibble(DribbleNibble),
  .ReceivedPacketTooBig(ReceivedPacketTooBig),
  .RxLength(RxLength),
  .LoadRxStatus(LoadRxStatus),
  .ReceivedPacketGood(ReceivedPacketGood),
  .AddressMiss(AddressMiss),
  .ReceivedPauseFrm(ReceivedPauseFrm),
  .RetryCntLatched(RetryCntLatched),
  .RetryLimit(RetryLimit),
  .LateCollLatched(LateCollLatched),
  .DeferLatched(DeferLatched),
  .RstDeferLatched(RstDeferLatched),
  .CarrierSenseLost(CarrierSenseLost)
);

task pulse_tx_status_write;
  begin
    force dut.TxStatusWrite = 1'b1;
    @(posedge WB_CLK_I);
    force dut.TxStatusWrite = 1'b0;
    @(posedge WB_CLK_I);
  end
endtask

integer i;

initial begin
  WB_CLK_I = 1'b0;
  forever #5 WB_CLK_I = ~WB_CLK_I;
end

initial begin
  MTxClk = 1'b0;
  MRxClk = 1'b0;
  forever #5 begin
    MTxClk = ~MTxClk;
    MRxClk = ~MRxClk;
  end
end

initial begin
  $dumpfile("tb_bd_overflow.vcd");
  $dumpvars(0, tb_bd_overflow);

  WB_DAT_I = 32'h0;
  WB_ADR_I = 8'h0;
  WB_WE_I = 1'b0;
  BDCs = 4'h0;
  Reset = 1'b1;

  m_wb_dat_i = 32'h0;
  m_wb_ack_i = 1'b0;
  m_wb_err_i = 1'b0;

  TxUsedData = 1'b0;
  TxRetry = 1'b0;
  TxAbort = 1'b0;
  TxDone = 1'b0;

  RxData = 8'h0;
  RxValid = 1'b0;
  RxStartFrm = 1'b0;
  RxEndFrm = 1'b0;
  RxAbort = 1'b0;

  r_TxEn = 1'b0;
  r_RxEn = 1'b0;
  r_TxBDNum = 8'd16;
  r_RxFlow = 1'b0;
  r_PassAll = 1'b0;

  InvalidSymbol = 1'b0;
  LatchedCrcError = 1'b0;
  RxLateCollision = 1'b0;
  ShortFrame = 1'b0;
  DribbleNibble = 1'b0;
  ReceivedPacketTooBig = 1'b0;
  RxLength = 16'h0;
  LoadRxStatus = 1'b0;
  ReceivedPacketGood = 1'b0;
  AddressMiss = 1'b0;
  ReceivedPauseFrm = 1'b0;

  RetryCntLatched = 4'h0;
  RetryLimit = 1'b0;
  LateCollLatched = 1'b0;
  DeferLatched = 1'b0;
  CarrierSenseLost = 1'b0;

  // Hold wrap low so TempTxBDAddress follows increment path.
  force dut.WrapTxStatusBit = 1'b0;

  #40;
  Reset = 1'b0;
  @(posedge WB_CLK_I);

  // -------- Baseline: bd_overflow_enable=0 -> linear increment --------
  dut.bd_overflow_enable = 1'b0;
  dut.TxBDAddress = 7'd0;

  for (i = 0; i < 4; i = i + 1) begin
    pulse_tx_status_write();
    if (dut.TxBDAddress !== (i + 1)) begin
      $display("BD_OVERFLOW_TEST_FAIL: expected linear TxBDAddress=%0d, got %0d", (i + 1), dut.TxBDAddress);
      $finish;
    end
  end

  $display("Baseline OK: linear TxBDAddress increment without bd_overflow_enable");

  // -------- Vulnerability: bd_overflow_enable=1 -> corrupted progression --------
  dut.bd_overflow_enable = 1'b1;
  dut.TxBDAddress = 7'd0;

  pulse_tx_status_write(); // expect 1
  if (dut.TxBDAddress !== 7'd1) begin
    $display("BD_OVERFLOW_TEST_FAIL: expected TxBDAddress=1, got %0d", dut.TxBDAddress);
    $finish;
  end

  pulse_tx_status_write(); // expect 3
  if (dut.TxBDAddress !== 7'd3) begin
    $display("BD_OVERFLOW_TEST_FAIL: expected TxBDAddress=3, got %0d", dut.TxBDAddress);
    $finish;
  end

  pulse_tx_status_write(); // expect 7
  if (dut.TxBDAddress !== 7'd7) begin
    $display("BD_OVERFLOW_TEST_FAIL: expected TxBDAddress=7, got %0d", dut.TxBDAddress);
    $finish;
  end

  pulse_tx_status_write(); // expect 15
  if (dut.TxBDAddress !== 7'd15) begin
    $display("BD_OVERFLOW_TEST_FAIL: expected TxBDAddress=15, got %0d", dut.TxBDAddress);
    $finish;
  end

  $display("VULNERABILITY CONFIRMED: bd_overflow_enable corrupts TxBDAddress progression");
  $display("BD_OVERFLOW_TEST_PASS");

  release dut.TxStatusWrite;
  release dut.WrapTxStatusBit;
  $finish;
end

endmodule

