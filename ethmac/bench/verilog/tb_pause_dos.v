//////////////////////////////////////////////////////////////////////
////                                                              ////
////  tb_pause_dos.v - Test Bench for PAUSE Frame DoS backdoor   ////
////                                                              ////
////  Verifies that enabling pause_dos_enable freezes PauseTimer  ////
////  decrement (DoS), while disabling it allows decrement.       ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "timescale.v"

module tb_pause_dos();

reg         MTxClk;
reg         MRxClk;
reg         TxReset;
reg         RxReset;
reg  [7:0]  RxData;
reg         RxValid;
reg         RxStartFrm;
reg         RxEndFrm;
reg         RxFlow;
reg         ReceiveEnd;
reg [47:0]  MAC;
reg         DlyCrcEn;
reg         TxDoneIn;
reg         TxAbortIn;
reg         TxStartFrmOut;
reg         ReceivedLengthOK;
reg         ReceivedPacketGood;
reg         TxUsedDataOutDetected;
reg         RxStatusWriteLatched_sync2;
reg         r_PassAll;
reg         pause_dos_enable;

wire        Pause;
wire        ReceivedPauseFrm;
wire        AddressOK;
wire        SetPauseTimer;

eth_receivecontrol dut (
  .MTxClk(MTxClk),
  .MRxClk(MRxClk),
  .TxReset(TxReset),
  .RxReset(RxReset),
  .RxData(RxData),
  .RxValid(RxValid),
  .RxStartFrm(RxStartFrm),
  .RxEndFrm(RxEndFrm),
  .RxFlow(RxFlow),
  .ReceiveEnd(ReceiveEnd),
  .MAC(MAC),
  .DlyCrcEn(DlyCrcEn),
  .TxDoneIn(TxDoneIn),
  .TxAbortIn(TxAbortIn),
  .TxStartFrmOut(TxStartFrmOut),
  .ReceivedLengthOK(ReceivedLengthOK),
  .ReceivedPacketGood(ReceivedPacketGood),
  .TxUsedDataOutDetected(TxUsedDataOutDetected),
  .Pause(Pause),
  .ReceivedPauseFrm(ReceivedPauseFrm),
  .AddressOK(AddressOK),
  .RxStatusWriteLatched_sync2(RxStatusWriteLatched_sync2),
  .r_PassAll(r_PassAll),
  .SetPauseTimer(SetPauseTimer),
  .pause_dos_enable(pause_dos_enable)
);

initial begin
  MTxClk = 1'b0;
  forever #7 MTxClk = ~MTxClk;
end

initial begin
  MRxClk = 1'b0;
  forever #5 MRxClk = ~MRxClk;
end

initial begin
  $dumpfile("tb_pause_dos.vcd");
  $dumpvars(0, tb_pause_dos);

  TxReset = 1'b1;
  RxReset = 1'b1;
  pause_dos_enable = 1'b0;
  RxData = 8'h00;
  RxValid = 1'b0;
  RxStartFrm = 1'b0;
  RxEndFrm = 1'b0;
  RxFlow = 1'b0;
  ReceiveEnd = 1'b0;
  MAC = 48'hAABBCCDDEEFF;
  DlyCrcEn = 1'b0;
  TxDoneIn = 1'b0;
  TxAbortIn = 1'b0;
  TxStartFrmOut = 1'b0;
  ReceivedLengthOK = 1'b0;
  ReceivedPacketGood = 1'b0;
  TxUsedDataOutDetected = 1'b0;
  RxStatusWriteLatched_sync2 = 1'b0;
  r_PassAll = 1'b0;

  #40;
  TxReset = 1'b0;
  RxReset = 1'b0;

  // Force SlotFinished high so DecrementPauseTimer is controlled only by pause_dos_enable.
  force dut.SlotFinished = 1'b1;

  // -------- Baseline: decrement works when pause_dos_enable=0 --------
  pause_dos_enable = 1'b0;
  @(negedge MRxClk) dut.PauseTimer = 16'd3;
  repeat (3) @(posedge MRxClk);

  if (dut.PauseTimer >= 16'd3) begin
    $display("PAUSE_DOS_TEST_FAIL: PauseTimer did not decrement when pause_dos_enable=0 (PauseTimer=%0d)", dut.PauseTimer);
    $finish;
  end
  $display("Baseline OK: PauseTimer decremented (PauseTimer=%0d)", dut.PauseTimer);

  // -------- Vulnerability: decrement blocked when pause_dos_enable=1 --------
  pause_dos_enable = 1'b1;
  @(negedge MRxClk) dut.PauseTimer = 16'd3;
  repeat (3) @(posedge MRxClk);

  if (dut.PauseTimer != 16'd3) begin
    $display("PAUSE_DOS_TEST_FAIL: PauseTimer changed with pause_dos_enable=1 (PauseTimer=%0d)", dut.PauseTimer);
    $finish;
  end

  $display("VULNERABILITY CONFIRMED: pause_dos_enable freezes PauseTimer decrement");
  $display("PAUSE_DOS_TEST_PASS");
  release dut.SlotFinished;
  $finish;
end

endmodule
