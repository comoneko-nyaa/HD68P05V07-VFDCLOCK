*--------------------------------------------------------------------
* HD68P05V07 VFD CLOCK
* Ver.1.0 20211225
* (c)comoneko
*--------------------------------------------------------------------

*********************************************************************
PortA		equ	$000
PortB		equ	$001
PortC		equ	$002
PortD		equ	$003
PortA_DR	equ	$004
PortB_DR	equ	$005
PortC_DR	equ	$006
PortD_AN	equ	$007
TimerDataReg	equ	$008
TimerCTRLReg	equ	$009
TCRBitIRQ	equ	7
TCRBitMask	equ	6
TXOUT		equ	4
RXIN		equ	0
RTSOUT		equ	5
CTSIN		equ	1

RAM_BASE	equ	$020
RAM_TOP		equ	$07F

ROM_BASE	equ	$080
ROM_TOP		equ	$F7F

VECTOR_TABLE	equ	$FF8

STACK_BASE	equ	RAM_TOP
STACK_PCL	equ	STACK_BASE
STACK_PCH	equ	STACK_BASE-1
STACK_INDEX	equ	STACK_BASE-2
STACK_ACCM	equ	STACK_BASE-3
STACK_CCR	equ	STACK_BASE-4

*define uses port
PortC_VFDHeater	equ	$40
PortC_HBLED	equ	$80
*********************************************************************
*********************************************************************
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*work valiables
		org	RAM_BASE
* Thread control	18uses
THContext0	rmb	4	*thread context save
THContext1	rmb	4	*  +0:ACCM
THContext2	rmb	4	*  +1:INDEX
THContext3	rmb	4	*  +2,+3:PCL/PCH
THNumber	rmb	1	*runnning thread number
THState		rmb	1	*thread status
THBitThNum	equ	$03	*running thread number in THState
notTHBitThNum	equ	$FC	*running thread number in THState
THBitTimerFlag	equ	7	*timer irq passing flag in THState
THBitClockTrig	equ	6	*1/100s triger
THBitSecFlag	equ	4	*1s flipflop
THBitWaitDummy	equ	0	*wait dummy
*VFD Display		11uses
VFDDigitScan	rmb	1	*VFD grid scan counter
VFDScanStartPos	rmb	1	*Scan Start Address offset 0-9
VFDDigitValue	rmb	9	*VFD digit data code
*purpose work		8uses
Work0		rmb	1	*purpose work
Work1		rmb	1	*
Work2		rmb	1	*
Work3		rmb	1	*
Work4		rmb	1	*
Work5		rmb	1	*
Work6		rmb	1	*
Work7		rmb	1	*
*clock variables	9uses
CLYear		rmb	2	*Year
CLMon		rmb	1	*month
CLDay		rmb	1	*day
CLHou		rmb	1	*Hour
CLMin		rmb	1	*minutes
CLSec		rmb	1	*seconds
CLmSec		rmb	1	*1/100 seconds
CLDispMode	rmb	1	*display mode
CLBitLeapYear	equ	3	*leap year flag in ThState
*button input work	3uses
BTLastData	rmb	2	*edge datect work
BTSetDigit	rmb	1	*setting digit position
BTPort		equ	PortD
BTMask		equ	$FC
BTSw1		equ	2
BTSw2		equ	3
BTSw3		equ	4
BTSw4		equ	5
BTSw5		equ	6
BTSw6		equ	7
ADJMode		equ	5	*clock adjust mode flag in THState
*UART BUFFER		12uses
UARTTxBuff	rmb	4
UARTRxBuff	rmb	4
UARTTxWPtr	rmb	1
UARTTxRPtr	rmb	1
UARTRxWPtr	rmb	1
UARTRxRPtr	rmb	1
*monitor work		12uses
MonWork		rmb	8
MonInpCnt	rmb	1
MonPerReg	rmb	1
MonGWork	rmb	2
MonRegA		rmb	1
MonRegX		rmb	1
MonSWIFlag	rmb	1
*Check LED		1uses
CLEDWork	rmb	1
*
*********************************************************************
*********************************************************************
*--------------------------------------------------------------------
*--------------------------------------------------------------------
		org	ROM_BASE
*--------------------------------------------------------------------
* VFD grid scan & segment port bit pattern table
*TABEL DATA		 1'fg2ed3  456.7,/8      cba9
VFDScanBitTbl	fcb	%11100110,%00010100,%00001110		*1 0
		fcb	%01001000,%00010100,%00001100		*2 1
		fcb	%01010111,%00010100,%00000110		*3 2
		fcb	%01010010,%10010100,%00001110		*4 3
		fcb	%01110000,%01010100,%00001100		*5 4
		fcb	%01110010,%00110100,%00001010		*6 5
		fcb	%01110110,%00011100,%00001010		*7 6
		fcb	%01100000,%00010101,%00001110		*8 7
		fcb	%01110110,%00010100,%00001111		*9 8
		fcb	%01110010,%00010100,%00001110		*  9
		fcb	%01110100,%00010100,%00001110		*  A
		fcb	%01110110,%00010100,%00001000		*  b
		fcb	%01100110,%00010100,%00000010		*  C
		fcb	%01010110,%00010100,%00001100		*  d
		fcb	%01110110,%00010100,%00000010		*  E
		fcb	%01110100,%00010100,%00000010		*  F
*                        1'fg2ed3  456.7,/8      cba9
		fcb	%01100110,%00010100,%00001010		*  G
		fcb	%01110100,%00010100,%00001100		*  H
		fcb	%01000000,%00010100,%00001000		*  i
		fcb	%01000110,%00010100,%00001100		*  J
		fcb	%01110100,%00010100,%00000000		*  k
		fcb	%01100110,%00010100,%00000000		*  L
		fcb	%01010100,%00010100,%00001000		*  n
		fcb	%01010110,%00010100,%00001000		*  o
		fcb	%01110100,%00010110,%00000110		*  P
		fcb	%01110000,%00010100,%00001110		*  q
		fcb	%01010100,%00010100,%00000000		*  r
		fcb	%01110110,%00010100,%00000000		*  t
		fcb	%01000110,%00010100,%00001000		*  u
		fcb	%01110010,%00010100,%00001100		*  y
*		fcb	%01000000,%00010110,%00000000		*  1/2
		fcb	%01010000,%00010100,%00000000		*  -
		fcb	%01000000,%00010100,%00000000		*  space

*monthly days table
CLMonthTable	fcb	31,28,31,30,31,30,31,31,30,31,30,31
CLSetMax	fcb	12,31,23,59,59,99
CLSetMin	fcb	 1, 1, 0, 0, 0, 0

VFDScnMsk0	equ	$89	*VFD grid bit masking
VFDScnMsk1	equ	$E9	*
VFDScnMsk2	equ	$01	*
VFDSegMsk0	equ	$36	*VFD segment bit mask
VFDSegMsk1	equ	$02	*
VFDSegMsk2	equ	$0E	*
VFDMsk0Dush	equ	$40	*VFD dush mask bit
VFDMsk1Com	equ	$10	*VFD commma mask bit
VFDMsk1Dp	equ	$04	*VFD dot mask bit
VFDSegCom	equ	$20	*comma code bit
VFDSegDush	equ	$40	*dush code bit
VFDSegDp	equ	$80	*dot code bit
VFDBitCom	equ	5	*comma code bit
VFDBitDush	equ	6	*dush code bit
VFDBitDp	equ	7	*dot code bit

VFDCHR_0	equ	0
VFDCHR_1	equ	1
VFDCHR_2	equ	2
VFDCHR_3	equ	3
VFDCHR_4	equ	4
VFDCHR_5	equ	5
VFDCHR_6	equ	6
VFDCHR_7	equ	7
VFDCHR_8	equ	8
VFDCHR_9	equ	9
VFDCHR_A	equ	10
VFDCHR_b	equ	11
VFDCHR_c	equ	12
VFDCHR_d	equ	13
VFDCHR_E	equ	14
VFDCHR_F	equ	15
VFDCHR_G	equ	16
VFDCHR_H	equ	17
VFDCHR_i	equ	18
VFDCHR_J	equ	19
VFDCHR_k	equ	20
VFDCHR_L	equ	21
VFDCHR_n	equ	22
VFDCHR_o	equ	23
VFDCHR_P	equ	24
VFDCHR_q	equ	25
VFDCHR_r	equ	26
VFDCHR_t	equ	27
VFDCHR_u	equ	28
VFDCHR_y	equ	29
*VFDCHR_12	equ	29
VFDCHR_MI	equ	30
VFDCHR_SPACE	equ	31
*********************************************************************
*********************************************************************
*--------------------------------------------------------------------
* sub routins
*--------------------------------------------------------------------
* Read vfd bit pattern table
*	Work0 = number 0-15
*	Work1 = Mask0
*	Work2 = Mask1
*	Work3 = Mask2
*	PORTA data
*	PORTB data
*	PORTC data
TBLRead		lda	Work0		*read display code
		lsla			*offset cal. code * 3
		add	Work0		*
		add	#VFDScanBitTbl
		tax			*move to index reg
		lda	,X		*1st data read
		and	Work1		*bit masking
		ora	PortA
		sta	PortA		*store 1st data
		incx			*next index address
		lda	,X 		*2nd data read
		and	Work2		*bit masking
		ora	PortB
		sta	PortB		*store 2nd data
		incx			*next index address
		lda	,X 		*3rd data read
		and	Work3		*bit masking
		ora	PortC
		sta	PortC		*store 3rd data
		rts
* Read vfd grid scan bit pattern table
*	Work0 = number 0-8
*	Work1 = x
*	Work2 = x
*	Work3 = x
TBLReadScan	lda	#VFDScnMsk0
		sta	Work1
		lda	#VFDScnMsk1
		sta	Work2
		lda	#VFDScnMsk2
		sta	Work3
		bra	TBLRead		*jump table read
* Read vfd grid scan bit pattern table
*	Work0 = number 0-15 & dot etc bit
*	Work1 = x
*	Work2 = x
*	Work3 = x
TBLReadSeg	lda	#VFDSegMsk0	*1st mask data set
		sta	Work1		*
		lda	#VFDSegMsk1	*
		sta	Work2		*2nd mask data set
		lda	#VFDSegMsk2	*3rd mask data set
		sta	Work3

		brclr	VFDBitCom,Work0,TBLRSeg00
		lda	Work2		*VFD common bit set
		ora	#VFDMsk1Com
		sta	Work2

TBLRSeg00	brclr	VFDBitDush,Work0,TBLRSeg01
		lda	Work1		*VFD dush bit set
		ora	#VFDMsk0Dush
		sta	Work1

TBLRSeg01	brclr	VFDBitDp,Work0,TBLRSeg02
		lda	Work2	*VFD dot bit set
		ora	#VFDMsk1Dp
		sta	Work2
TBLRSeg02	lda	Work0
		and	#$1F
		sta	Work0
		bra	TBLRead		*jump table read
*--------------------------------------------------------------------
*	BINARY to HEX
*	X = address(0000-00FF)
*	A	LSB(0-F)
*	X	MSB(0-F)
*--------------------------------------------------------------------
Bin2Hex		lda	,x
		tax
		lsrx
		lsrx
		lsrx
		lsrx
		and	#$0F
		rts
*	VFD DISPLAY
Bin2HexDisp	bsr	Bin2Hex
		stx	VFDDigitValue+7
		sta	VFDDigitValue+8
		rts
*	Ascii code
Bin2Ascii	bsr	Bin2Hex
		sta	Work7
		txa
		add	#$30
		cmp	#$3a
		bmi	Bin2Ascii00
		add	#$07
Bin2Ascii00	tax
		lda	Work7
		add	#$30
		cmp	#$3a
		bmi	Bin2Ascii01
		add	#$07
Bin2Ascii01	rts

*--------------------------------------------------------------------
*	HEX to BINARY
*	X = hex string top address
*	Work0 High byte Binary
*	Work1 Low byte Binary
*--------------------------------------------------------------------
Hex2Bin		lda	#$8		*space pass
		sta	Work2		*
H2B00		lda	,X		*
		cmp	#$30		* < 0
		bpl	H2B01		*
		incx			*
		dec	Work2		*
		bne	H2B00		*
		bra	H2BEND		*
H2B01		stx	Work3		*a->A convart
		lda	#$8		*
		sta	Work2		*
H2B02		lda	,X		*
		cmp	#$30		* < 0
		bmi	H2B04		* 
		cmp	#$47		*>= G
		bmi	H2B03		*
		sub	#$20		*
		sta	,X		*
H2B03		incx			*
		dec	Work2		*
		bne	H2B02		*
		bra	H2BEND		*
H2B04		ldx	Work3		*
		clr	Work0		*
		clr	Work1		*
		lda	#$4		*
		sta	Work2		*
H2B05		lda	,X		*
		cmp	#$30		*term detect
		bmi	H2BEND		*
		clc			*clear carry
		rol	Work1		*
		rol	Work0		*
		rol	Work1		*
		rol	Work0		*
		rol	Work1		*
		rol	Work0		*
		rol	Work1		*
		rol	Work0		*
		sub	#$30		*-$30
		cmp	#$0a		* > 9
		bmi	H2B06		*
		sub	#$07		* -7
H2B06		ora	Work1		*
		sta	Work1		*
		incx			*
		dec	Work2		*
		bne	H2B05		*
H2BEND		rts
*--------------------------------------------------------------------
*16bit sub
*work7,6 = work7,6 - wokrk5,4
*--------------------------------------------------------------------
LIBSub16	lda	Work6
		sub	Work4
		sta	Work6
		lda	Work7
		sbc	Work5
		sta	Work7
		rts
*********************************************************************
*--------------------------------------------------------------------
*	debug LED
*--------------------------------------------------------------------
CheckLED	sta	CLEDWork		*5
		lda	PortC			*4
		eor	#PortC_HBLED		*2
		swi
		sta	PortC			*5
		lda	CLEDWork		*4
		rts				*6
*********************************************************************
*--------------------------------------------------------------------
*
*Timer IRQ
*
*--------------------------------------------------------------------
TIMER_IRQ	bclr	TCRBitIRQ,TimerCTRLReg		*irq clear
		bset	THBitTimerFlag,THState		*passing flag set
		rti
*--------------------------------------------------------------------
*
*INT_IRQ
*
*--------------------------------------------------------------------
INT_IRQ
		rti
*--------------------------------------------------------------------
*
*SWI
*
*--------------------------------------------------------------------
SWI_IRQ		jmp	MonitorSWI
*--------------------------------------------------------------------
*********************************************************************
*********************************************************************
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*thread switch entry
*--------------------------------------------------------------------
THSwitch
*context save
		sei			*irq disable
		sta	STACK_ACCM
		stx	STACK_INDEX
		lda	THNumber	*get running thread number
		and	#THBitThNum	*
		lsla			* context save work address cal
		lsla			* x4
		add	#THContext0	*base address add
		tax			*move to index reg
		lda	STACK_ACCM
		sta	,X		*store stack data
		incx
		lda	STACK_INDEX	*
		sta	,X		*
		incx
		lda	STACK_PCH	*
		sta	,X		*
		incx
		lda	STACK_PCL	*
		sta	,X		*
		cli			*irq enable
*post thread call
		jsr	ThreadPost
*1/100 triger
		lda	THNumber	*thread number 3bit mask
		and	#$07		*
		bne	THTrig00	*all bit zero. set flag
		bset	THBitClockTrig,THState
THTrig00
*next thread context load
		inc	THNumber	*incliment thread number
THStart
		sei			*irq disable
		lda	THNumber	*get running thread number
		and	#THBitThNum	*
		lsla			* context save work address cal
		lsla			* x4
		add	#THContext0+3	*base address add
		tax			*move to index reg
		lda	,X		*reload stack data
		sta	STACK_PCL	*
		decx			*
		lda	,X		*
		sta	STACK_PCH	*
		decx			*
		lda	,X		*
		sta	STACK_INDEX	*
		decx			*
		lda	,X		*
		ldx	STACK_INDEX	*
		cli			*irq enable
*wait timerup
SWIWaitTimerUp	brclr	THBitTimerFlag,THState,SWIWaitTimerUp
		bclr	THBitTimerFlag,THState
*pre thread call
		jsr	ThreadPre
*return next thread
		rts
*--------------------------------------------------------------------
*********************************************************************
*********************************************************************
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*
*MAIN
*
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*--------------------------------------------------------------------
START
		sei
*--------------------------------------------------------------------
*Peripheral initialize
* PORT
		lda	#$FF
		sta	PortA_DR
		sta	PortB_DR
		sta	PortC_DR
		clr	PortA
		clr	PortB
		clr	PortC
* Timer
		lda	#$30
		sta	TimerCTRLReg
		lda	#$FF
		sta	TimerDataReg
* External INT
	
*work initialize
*display work init
		clr	VFDDigitScan
		clr	VFDDigitValue+0
		clr	VFDDigitValue+1
		clr	VFDDigitValue+2
		clr	VFDDigitValue+3
		clr	VFDDigitValue+4
		clr	VFDDigitValue+5
		clr	VFDDigitValue+6
		clr	VFDDigitValue+7
		clr	VFDDigitValue+8
		clr	VFDScanStartPos
*clock work init
		clr	CLmSec
		clr	CLSec
		clr	CLMin
		clr	CLHou
		clr	CLDispMode
		lda	#1
		sta	CLDay
		sta	CLMon
		lda	#$e6
		sta	CLYear
		lda	#$07
		sta	CLYear+1
*button input
		lda	#$FF
		sta	BTLastData
		sta	BTLastData+1
*thread initialize
		clr	THNumber
		clr	THState
		clr	THContext0
		clr	THContext0+1
		clr	THContext1
		clr	THContext1+1
		clr	THContext2
		clr	THContext2+1
		clr	THContext3
		clr	THContext3+1
		lda	#Thread0Exec/256
		sta	THContext0+2
		lda	#Thread0Exec&$FF
		sta	THContext0+3
		lda	#Thread1Exec/256
		sta	THContext1+2
		lda	#Thread1Exec&$FF
		sta	THContext1+3
		lda	#Thread2Exec/256
		sta	THContext2+2
		lda	#Thread2Exec&$FF
		sta	THContext2+3
		lda	#Thread3Exec/256
		sta	THContext3+2
		lda	#Thread3Exec&$FF
		sta	THContext3+3
		rsp
*UART INIT	
		jsr	UARTInit

*Monitor init
		jsr	MonitorIni

		cli			*IRQ enable
		jsr	THStart
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*pre thread
*--------------------------------------------------------------------
ThreadPre
*--------------------------------------------------------------------
* VFD display scan
*--------------------------------------------------------------------
		clr	PortA		*off vfd display
		clr	PortB		*
		lda	#$F0		*
		and	PortC		*
		sta	PortC		*
		lda	VFDDigitScan	*digit segment data offset calc.
		add	VFDScanStartPos	*
		bmi	THPre02		* value range check
		cmp	#9		*
		bpl	THPre02		*
		add	#VFDDigitValue	*
		tax			*
		lda	,X		*
		bra	THPre03		*
THPre02		lda	#VFDCHR_SPACE	*
THPre03		sta	Work0		*set value
		jsr	TBLReadSeg	*set segment pattern
		lda	VFDDigitScan	*grid pattern data
		sta	Work0		*
		jsr	TBLReadScan	*set grid scan pattern
		lda	VFDDigitScan	*incriment scan count
		cmp	#8		*
		beq	THPre00		*
		inca			*
		bra	THPre01		*
THPre00		lda	PortC		*toggle VFD heater voltage
		eor	#PortC_VFDHeater
		sta	PortC		*
		clra			*
THPre01		sta	VFDDigitScan	*
		rts			*
*--------------------------------------------------------------------
*post thread
*--------------------------------------------------------------------
ThreadPost
*offset scroll proc
		lda	THNumber
		and	#$1f
		cmp	#$1f
		bne	THPost01
		tst	VFDScanStartPos
		beq	THPost01
		bmi	THPost02	*pos incriment
		dec	VFDScanStartPos
		rts
THPost02	inc	VFDScanStartPos
THPost01	rts
*--------------------------------------------------------------------
*--------------------------------------------------------------------

*--------------------------------------------------------------------
*thread 0 exec entry
Thread0Exec
		jsr	THSwitch
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*clock count
*--------------------------------------------------------------------
		lda	CLmSec
		cmp	#50
		bmi	CL08
		bclr	THBitSecFlag,THState
		bra	CL09
CL08		bset	THBitSecFlag,THState
CL09		brclr	THBitClockTrig,THState,Thread0Exec	*check 1/100 trig
		bclr	THBitClockTrig,THState
		brclr	ADJMode,THState,CLCountUp		*adjust mode check
		jmp	CL07					*adjust mode pass count up
CLCountUp	lda	CLmSec		*up count miliseconds
		inca			*
		cmp	#100		*if 100 over branch
		bhs	CL00		*
		sta	CLmSec		*
		bra	CL07		*
CL00		clr	CLmSec		*1/100 zero clear
		lda	CLSec		*up count seconds
		inca			*
		cmp	#60		*60 over ?
		bhs	CL01		*
		sta	CLSec		*
		bra	CL07		*
CL01		clr	CLSec		*sec zero clear
		lda	CLMin		*up count minuts
		inca			*
		cmp	#60		*60 over ?
		bhs	CLC02		*
		sta	CLMin		*
		bra	CL07		*
CLC02		clr	CLMin		*Min zero clear
		lda	CLHou		*up count Houre
		inca			*
		cmp	#24		*24 over ?
		bhs	CL03		*
		sta	CLHou		*
		bra	CL07		*
CL03		clr	CLHou		*houre reset
		jsr	CLCheckLeapYear *check leap year
		ldx	CLMon		*read monthly days
		decx			*
		lda	#CLMonthTable,X	*
		decx			*leap 2 month 29day
		bne	CL04		*
		brclr	CLBitLeapYear,THState,CL04
		inca			*
CL04		sta	Work0		*
		lda	CLDay		*day count up
		inca			*
		cmp	Work0		*
		bhi	CL05		*
		sta	CLDay		*
		bra	CL07		*
CL05		lda	#1		*day count reaset
		sta	CLDay		*
		lda	CLMon		*count up month
		inca			*
		cmp	#12		*
		bhi	CL06		*
		sta	CLMon		*
		bra	CL07		*
CL06		lda	#1		*reset month count
		sta	CLMon		*
		lda	CLYear		*year count up
		add	#1		*
		sta	CLYear		*
		bcc	CL07		*
		inc	CLYear+1	*
CL07		jmp	Thread0Exec
*leap year check routin
*check 4year cycle only
CLCheckLeapYear
		lda	CLYear		*load year data lower byte
		and	#$03
		beq	CLCheckLY00
		bclr	CLBitLeapYear,THState
		rts
CLCheckLY00	bset	CLBitLeapYear,THState
		rts
*--------------------------------------------------------------------
*thread 1 exec entry
Thread1Exec
		jsr	THSwitch
		jmp	MonitorMes00
*--------------------------------------------------------------------
*--------------------------------------------------------------------
*button input
*--------------------------------------------------------------------
ButtunProc	jsr	THSwitch
		lda	BTPort		*read switch port
		and	#BTMask
		tax
		and	BTLastData	*cancel chattering
		stx	BTLastData
		coma
		tax
		sta	Work0
		eor	BTLastData+1	*push edge detect
		and	Work0
		stx	BTLastData+1
		sta	Work0		*button push branch
		brset	BTSw1,Work0,BTPush1
		brset	BTSw2,Work0,BTPush2
		brset	BTSw3,Work0,BTPush3
		brset	BTSw4,Work0,BTPush4
		brset	BTSw5,Work0,BTPush5
		brset	BTSw6,Work0,BTPush6
		jmp	MonitorTask
*down value
BTPush1		jsr	THSwitch
		brset	ADJMode,THState,BT100
		jmp	ButtunProc
BT100		clra			*dec
		jmp	BTIncDec
*up value
BTPush2		jsr	THSwitch
		brset	ADJMode,THState,BT200
		jmp	ButtunProc
BT200		lda	#1
		jmp	BTIncDec
*edit value move date
BTPush3		jsr	THSwitch
		brset	ADJMode,THState,BT300
		jmp	ButtunProc
BT300		lda	CLDispMode
		deca
		cmp	#5
		bmi	BT301
		dec	CLDispMode
		lda	#$09
		sta	VFDScanStartPos
BT301		jmp	ButtunProc
*edit value move time
BTPush4		jsr	THSwitch
		brset	ADJMode,THState,BT400
		jmp	ButtunProc
BT400		lda	CLDispMode
		cmp	#11
		bpl	BT401	
		inc	CLDispMode
		lda	#$F7
		sta	VFDScanStartPos
BT401		jmp	ButtunProc
*adjust mode on/off
BTPush5		jsr	THSwitch
		brset	ADJMode,THState,BT500
BT501		lda	#5		*date&time set display mode
		sta	CLDispMode
		bset	ADJMode,THState	*
		jmp	ButtunProc	*
BT500		bclr	ADJMode,THState	*adjust mode disable
		clr	CLDispMode
		jmp	ButtunProc	*
*Display mode change
BTPush6		jsr	THSwitch	*
		brclr	ADJMode,THState,BT602
		jmp	ButtunProc	*adjust mode not change display mode
BT602		lda	CLDispMode
		inca
		cmp	#5
		bmi	BT601
BT600		lda	#0
BT601		sta	CLDispMode
		lda	#$F7
		sta	VFDScanStartPos
		jmp	ButtunProc
*value inc/dec 
* A reg 0:dec 1:inc
BTIncDec	sta	Work3
		lda	CLDispMode
		cmp	#5
		beq	BTID01		*year 16bit
		sub	#6		*max set value table read
		sta	Work0		*
		lda	#CLSetMax	*
		add	Work0		*
		tax			*
		lda	,X		*
		sta	Work1		*
		lda	#CLSetMin	*min set value table read
		add	Work0		*
		tax			*
		lda	,X		*
		sta	Work4		*
		lda	Work0		*
		cmp	#1		*day setmode check
		bne	BTID02		*
		lda	CLMon		*table read month days
		deca			*
		add	#CLMonthTable	*
		tax			*
		lda	,X		*
		sta	Work1		*day max value
		lda	CLMon		*leap year check
		cmp	#2		*
		bne	BTID02		*
		jsr	CLCheckLeapYear	*
		brclr	CLBitLeapYear,THState,BTID02
		inc	Work1		*feb days 29
BTID02		lda	#CLMon		*value address calc
		add	Work0		*
		tax			*
		tst	Work3		*inc or dec
		beq	BTID03		*jmp dec
		inc	,X		*inc
		lda	Work1		*check max value
		inca			*
		cmp	,X		*
		bne	BTID07		*
		lda	Work4		*if max over set value min
		sta	,X		*
BTID07		jmp	ButtunProc	*
BTID03		lda	,X		*dec
		cmp	Work4		*check min value
		bne	BTID04		*
		lda	Work1		*if min under set value max
		sta	,X		*
		jmp	ButtunProc	*
BTID04		dec	,X		*
		jmp	ButtunProc	*

BTID01		tst	Work3		*year inc/dec
		beq	BTID05
		inc	CLYear		*INC
		tst	CLYear
		bne	BTID06
		inc	CLYear+1
		bra	BTID06
BTID05		dec	CLYear		*dec
		lda	CLYear
		coma
		bne	BTID06
		dec	CLYear+1
BTID06		jmp	ButtunProc

*--------------------------------------------------------------------
*thread 2 exec entry
Thread2Exec
*--------------------------------------------------------------------
*		jsr	THSwitch
*--------------------------------------------------------------------
*----clock display data make
CLDisplay	jsr	THSwitch
		lda	CLDispMode		*normal display
		beq	CLDisp24_jmp		* mode 0
		deca
		beq	CLDisp12_jmp		* mode 1
		deca
		beq	CLDispDate_jmp		* mode 2
		deca
		beq	CLDisp48_jmp		* mode 3
		deca
		beq	CLDispDT_jmp		* mode 4
		deca				*setup display
		beq	CLDispY_jmp		*
		deca				*
		beq	CLDispM_jmp		*
		deca				*
		beq	CLDispD_jmp		*
		deca				*
		beq	CLDispH_jmp		*
		deca				*
		beq	CLDispMI_jmp		*
		deca				*
		beq	CLDispS_jmp		*
		deca				*
		beq	CLDispMS_jmp		*
*no display
		jmp	Thread2Exec
CLDisp24_jmp	jmp	CLDispTime24
CLDisp12_jmp	jmp	CLDispTime12
CLDispDate_jmp	jmp	CLDispDate
CLDisp48_jmp	jmp	CLDisp48
CLDispDT_jmp	jmp	CLDispDandT
CLDispY_jmp	jmp	CLDispYear
CLDispM_jmp	jmp	CLDispMonth
CLDispD_jmp	jmp	CLDispDay
CLDispH_jmp	jmp	CLDispHour
CLDispMI_jmp	jmp	CLDispMin
CLDispS_jmp	jmp	CLDispSec
CLDispMS_jmp	jmp	CLDispMSec
*clock display time only
*hh:mm:ss.ms
CLDispTime24	jsr	THSwitch
		jsr	CLDotBlank
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue
		lda	CLHou			*hour
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+1		*
		lda	Work0			*
		ora	Work4			*
		sta	VFDDigitValue+2		*
CLDispMin24	lda	CLMin			*minutes
		jsr	CLBin2Dec		*
		lda	Work1			*
		ora	Work5			*
		sta	VFDDigitValue+3		*
		lda	Work0			*
		ora	Work4			*
		sta	VFDDigitValue+4		*
		lda	CLSec			*seconds
		jsr	CLBin2Dec		*
		lda	Work1			*
		ora	Work5			*
		sta	VFDDigitValue+5		*
		lda	Work0			*
		ora	Work6			*
		sta	VFDDigitValue+6		*
		lda	CLmSec			*miliseconds
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+7		*
		lda	Work0			*
		sta	VFDDigitValue+8		*
		jmp	Thread2Exec
*APhh:mm:ss.ms
CLDispTime12	jsr	THSwitch
		jsr	CLDotBlank
		lda	CLHou			*hour
		cmp	#12			*AM/PM check
		bmi	CLDispT01		*branch AM
		ldx	#VFDCHR_P		*
		stx	VFDDigitValue		*
		sub	#12			*
		bne	CLDispT00		*0->12
		lda	#12			*
CLDispT00	jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+1		*
		lda	Work0			*
		ora	Work4			*
		sta	VFDDigitValue+2		*
		jmp	CLDispMin24
CLDispT01	ldx	#VFDCHR_A		*
		stx	VFDDigitValue		*
		tsta				*
		bne	CLDispT00		*0->12
		lda	#12			*
CLDispT02	bra	CLDispT00		*
*clock display date only
CLDispDate	jsr	THSwitch
		jsr	CLDotBlank
		ldx	#CLYear			*Year
		jsr	CLBin2Dec2		*
		lda	Work3			*
		sta	VFDDigitValue		*
		lda	Work2			*
		sta	VFDDigitValue+1		*
		lda	Work1			*
		sta	VFDDigitValue+2		*
		lda	Work0			*
		sta	VFDDigitValue+3		*
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+4
		lda	CLMon			*month
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+5		*
		lda	Work0			*
		sta	VFDDigitValue+6		*
		lda	CLDay			*day
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+7		*
		lda	Work0			*
		sta	VFDDigitValue+8		*
		jmp	Thread2Exec
*clock display day & 48houre time
CLDisp48	jsr	THSwitch
		jsr	CLDotBlank
		lda	CLHou			*check 0-5 hour
		cmp	#5			*
		bpl	CLD48_07		*
		lda	CLDay			*day check 1 or term
		deca				*
		deca				*
		bpl	CLD48_05		*
CLD48_01	lda	CLMon			*befor month
		deca				*
		bne	CLD48_03		*year check
		lda	#11			*
CLD48_03	sta	Work0
		add	#CLMonthTable		*read monthly days
		tax				*
		ldx	,X			*
		lda	Work0			*leap 2 month 29day
		deca				*
		bne	CLD48_06		*
		brclr	CLBitLeapYear,THState,CLD48_02
		incx
CLD48_06	txa				*
		bra	CLD48_02		*
CLD48_07	lda	CLDay			*normal
		bra	CLD48_02		*
CLD48_05	lda	CLDay			*0 to 5 houre
		deca
CLD48_02	jsr	CLBin2Dec
		lda	Work1			*Day
		sta	VFDDigitValue		*
		lda	Work0			*
		sta	VFDDigitValue+1		*
		lda	#VFDCHR_SPACE		*space
		sta	VFDDigitValue+2		*
		lda	CLHou			*hour
		cmp	#5
		bpl	CLD48_04		*
		add	#24
CLD48_04	jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+3		*
		lda	Work0			*
		ora	Work4			*
		sta	VFDDigitValue+4		*
		lda	CLMin			*minutes
		jsr	CLBin2Dec		*
		lda	Work1			*
		ora	Work5			*
		sta	VFDDigitValue+5		*
		lda	Work0			*
		ora	Work4			*
		sta	VFDDigitValue+6		*
		lda	CLSec			*seconds
		jsr	CLBin2Dec		*
		lda	Work1			*
		ora	Work5			*
		sta	VFDDigitValue+7		*
		lda	Work0			*
		sta	VFDDigitValue+8		*
		jmp	Thread2Exec
*clock display month day houre minutes
CLDispDandT	jsr	THSwitch
		jsr	CLDotBlank
		lda	CLMon			*month
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue		*
		lda	Work0			*
		sta	VFDDigitValue+1		*
		lda	CLDay			*day
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+2		*
		lda	Work0			*
		sta	VFDDigitValue+3		*
		lda	#VFDCHR_SPACE		*space
		sta	VFDDigitValue+4		*
		lda	CLHou			*hour
		jsr	CLBin2Dec		*
		lda	Work1			*
		sta	VFDDigitValue+5		*
		lda	Work0			*
		ora	Work4			*
		sta	VFDDigitValue+6		*
		lda	CLMin			*minutes
		jsr	CLBin2Dec		*
		lda	Work1			*
		ora	Work5			*
		sta	VFDDigitValue+7		*
		lda	Work0			*
		sta	VFDDigitValue+8		*
		jmp	Thread2Exec
*binary byte to 2 decimal digit (0 - 99)
* CALL A:binary
* RETURN work0 lower digit : work1 upper digit
* work0 work1 uses
CLBin2Dec	clr	Work1		*
CLB2D00		tax			*a->x
		sub	#10		*a-10
		bmi	CLB2D01		*a<0
		inc	Work1		*work0++
		bra	CLB2D00		*
CLB2D01		stx 	Work0		*
		rts			*
*binary byte to 4 decimal digit (0 - 9999)
* CALL X:binary address(2byte data)
* RETURN work0-work3
CLBin2Dec2	clr	Work3		*counter clear
		clr	Work2		*
		lda	,X		*data read
		sta	Work6		*
		lda	1,x		*
		sta	Work7		*
		lda	#$03		*set 1000
		sta	Work5		*
		lda	#$E8		*
		sta	Work4		*
CLB2D200	lda	Work7		*1000
		sta	Work1		*
		lda	Work6		*
		sta	Work0		*
		jsr	LIBSub16	*
		bmi	CLB2D201	*
		inc	Work3		*
		bra	CLB2D200	*
CLB2D201	lda	#$00		*set 100
		sta	Work5		*
		lda	#$64		*
		sta	Work4		*
		lda	Work1		*
		sta	Work7		*
		lda	Work0		*
		sta	Work6		*
CLB2D202	lda	Work7		*100
		sta	Work1		*
		lda	Work6		*
		sta	Work0		*
		jsr	LIBSub16	*
		bmi	CLB2D203	*
		inc	Work2		*
		bra	CLB2D202	*
CLB2D203	lda	Work0		*10
		bsr	CLBin2Dec
		rts
*dot blanking
*
CLDotBlank	clr	Work4
		clr	Work5
		clr	Work6
		brclr	THBitSecFlag,THState,CLDtBl01
		lda	##VFDSegDp+VFDSegCom	*
		sta	Work4			*
		lda	#VFDSegDush		*
		sta	Work5			*
CLDtBl01	lda	#VFDSegDp		*
		sta	Work6			*
		rts
*setup display
* year
CLDispYear	lda	#VFDCHR_y
		sta	VFDDigitValue
		lda	#VFDCHR_E
		sta	VFDDigitValue+1
		lda	#VFDCHR_A
		sta	VFDDigitValue+2
		lda	#VFDCHR_r
		sta	VFDDigitValue+3
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+4
		ldx	#CLYear
		jsr	CLBin2Dec2
		lda	Work3
		sta	VFDDigitValue+5
		lda	Work2
		sta	VFDDigitValue+6
		lda	Work1
		sta	VFDDigitValue+7
		lda	Work0
		sta	VFDDigitValue+8
		jmp	Thread2Exec		
* month
CLDispMonth	lda	#VFDCHR_r
		sta	VFDDigitValue
		lda	#VFDCHR_n
		sta	VFDDigitValue+1
		lda	#VFDCHR_o
		sta	VFDDigitValue+2
		lda	#VFDCHR_n
		sta	VFDDigitValue+3
		lda	#VFDCHR_t
		sta	VFDDigitValue+4
		ldx	#CLMon
		jmp	CLDispSetCommon
* day
CLDispDay	lda	#VFDCHR_d
		sta	VFDDigitValue
		lda	#VFDCHR_A
		sta	VFDDigitValue+1
		lda	#VFDCHR_y
		sta	VFDDigitValue+2
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+3
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+4
		ldx	#CLDay
		jmp	CLDispSetCommon
* hour
CLDispHour	lda	#VFDCHR_H
		sta	VFDDigitValue
		lda	#VFDCHR_o
		sta	VFDDigitValue+1
		lda	#VFDCHR_u
		sta	VFDDigitValue+2
		lda	#VFDCHR_r
		sta	VFDDigitValue+3
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+4
		ldx	#CLHou
		jmp	CLDispSetCommon
*minitu
CLDispMin	lda	#VFDCHR_r
		sta	VFDDigitValue
		lda	#VFDCHR_n
		sta	VFDDigitValue+1
		lda	#VFDCHR_i
		sta	VFDDigitValue+2
		lda	#VFDCHR_n
		sta	VFDDigitValue+3
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+4
		ldx	#CLMin
		jmp	CLDispSetCommon
*second
CLDispSec	lda	#VFDCHR_5
		sta	VFDDigitValue
		lda	#VFDCHR_E
		sta	VFDDigitValue+1
		lda	#VFDCHR_c
		sta	VFDDigitValue+2
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+3
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+4
		ldx	#CLSec
		jmp	CLDispSetCommon
*milisecond
CLDispMSec	lda	#VFDCHR_r
		sta	VFDDigitValue
		lda	#VFDCHR_n
		sta	VFDDigitValue+1
		lda	#VFDCHR_i
		sta	VFDDigitValue+2
		lda	#VFDCHR_1
		sta	VFDDigitValue+3
		lda	#VFDCHR_i
		sta	VFDDigitValue+4
		ldx	#CLmSec
		jmp	CLDispSetCommon
*common rutin
* x reg value address
CLDispSetCommon
		lda	,X
		jsr	CLBin2Dec
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+5
		lda	#VFDCHR_SPACE
		sta	VFDDigitValue+6
		lda	Work1
		sta	VFDDigitValue+7
		lda	Work0
		sta	VFDDigitValue+8
		jmp	Thread2Exec

*--------------------------------------------------------------------
*thread 3 exec entry
Thread3Exec
*--------------------------------------------------------------------
*		jsr	THSwitch
*		bra	Thread3Exec
*UART MODULE
* 19.2kbps
UARTTask
		jsr	THSwitch
*Send process
UARTTxTask	jsr	UARTTxEmptyCheck	*check send data request
		bcc	UARTRxTask		*no request goto rx process
		sei				*irq disable
UARTTx00	brset	CTSIN,PortD,UARTTxEnd	*check hand shake
		jsr	UARTTxRead		*buffer read
		tax				*
		lda	#$8			*send bit count value
		bclr	TXOUT,PortC		*7 start bit
		nop				*2 wait
		nop				*2 wait
		nop				*2 wait
		nop				*2 wait
		nop				*2 wait
		jsr	UARTWait27		*27 wait
UARTTx01	rorx				*4 data shift
		bcc	UARTTx02		*4 data 0/1 check
		bset	TXOUT,PortC		*7 out data 1
		bra	UARTTx03		*4
UARTTx02	bclr	TXOUT,PortC		*7 out data 0
		nop				*2 wait
		nop				*2 wait
UARTTx03	jsr	UARTWait27		*27 wait
		sub	#$01			*2 bit shift count
		bne	UARTTx01		*4 shift loop check
		nop				*2 wait
		nop				*2 wait
		bset	TXOUT,PortC		*7 stop bit
		jsr	UARTWait27		*27 wait
		jsr	UARTWait25		*25 wait
		cli				*irq enable
		jsr	THSwitch		* switch thread
		sei				*irq disable
		jsr	UARTTxEmptyCheck	*
		bcs	UARTTx00		*
UARTTxEnd	cli				*irq enable
		jsr	THSwitch		* switch thread
*Recieve process
UARTRxTask
		jsr	UARTRxEmptyCheck
		bcs	UARTRxEnd
		sei				*irq disable
		lda	#28			*check loop wait time value
		bclr	RTSOUT,PortC		*RTS enable
UARTRx00	brclr	RXIN,PortD,UARTRx01	*10 check start bit
		sub	#$01			*2   loop time 104uS
		bne	UARTRx00		*4
		bset	RTSOUT,PortC		*RTS disable
		bra	UARTRxEnd		*
UARTRx01	bset	RTSOUT,PortC		*7 RTS disable
		bsr	UARTWait27		*20
		bsr	UARTRxSub		*28
		bsr	UARTWait24		*24
		bsr	UARTRxSub		*28
		bsr	UARTWait24		*24
		bsr	UARTRxSub		*28
		bsr	UARTWait24		*24
		bsr	UARTRxSub		*28
		bsr	UARTWait20		*20
		bsr	UARTRxSub		*28
		bsr	UARTWait20		*20
		bsr	UARTRxSub		*28
		bsr	UARTWait22		*22
		bsr	UARTRxSub		*28
		bsr	UARTWait22		*22
		bsr	UARTRxSub		*28
		bsr	UARTWait22		*22
		bsr	UARTWait52		*52
UARTRx05	cli				*irq enable
		jsr	UARTRxWrite		*write buffer
		bcc	UARTRxEnd		*
		jsr	THSwitch		*buffer write retry
		bra	UARTRx05		*
UARTRxEnd	cli				*irq enable
		jmp	UARTTask

UARTRxSub	lsra				*2  total 28 clock
		brclr	RXIN,PortD,UARTRxS00	*10
		ora	#$80			*2
		rts				*6
UARTRxS00	and	#$7f			*2
UARTRxSub01	rts				*6 

*uart wait subrutin
UARTWait52	nop				*2
UARTWait50	nop				*2
UARTWait48	bset	THBitWaitDummy,THState	*7
		bset	THBitWaitDummy,THState	*7
UARTWait34	bset	THBitWaitDummy,THState	*7
UARTWait27	nop				*2 2
UARTWait25	nop				*2 4
UARTWait23	nop				*2 6
		bclr	THBitWaitDummy,THState	*7 13
		rts				*6 19 + bsr 8 = 27
UARTWait24	nop				*2
UARTWait22	nop				*2
UARTWait20	nop				*2
UARTWait18	nop				*2
UARTWait16	nop				*2
UARTWait14	rts				*6

*uart init subrutin
UARTInit	bset	TXOUT,PortC
		bset	RTSOUT,PortC
		clr	UARTTxWPtr
		clr	UARTTxRPtr
		clr	UARTRxWPtr
		clr	UARTRxRPtr
		clr	UARTTxBuff
		clr	UARTTxBuff+1
		clr	UARTTxBuff+2
		clr	UARTTxBuff+3
		clr	UARTRxBuff
		clr	UARTRxBuff+1
		rts

*check txbuffer
* cflag 0:empty 1:not empty
UARTTxEmptyCheck
		lda	UARTTxRPtr
		cmp	UARTTxWPtr
		beq	UARTTxECK00
		sec
		rts
UARTTxECK00	clc
		rts
*check rxbuffer
* cflag 0:empty 1:not empty
UARTRxEmptyCheck
		lda	UARTRxWPtr
		inca
		and	#$03
		cmp	UARTRxRPtr
		bne	UARTRxECK00
		sec
		rts
UARTRxECK00	clc
		rts
*Tx write buffer 1 byte
* A<-data
* CFlag->0:success 1:failure
UARTTxWrite	
		tax				*
		lda	UARTTxWPtr		*buffer check
		inca				*
		and	#$03			*
		cmp	UARTTxRPtr		*
		beq	UARTTxW00		*buffer full
		lda	UARTTxWPtr		*buffer address calc
		add	#UARTTxBuff		*
		sta	Work7			*
		lda	UARTTxWPtr		*inc write pointer
		inca				*
		and	#$03			*
		sta	UARTTxWPtr		*
		txa				*write buffer data address recav
		ldx	Work7			*
		sta	,X			*set data
		clc				*c flag clear
		rts				*
UARTTxW00	txa				*
		sec				*c flag set
		rts				*
*Tx read buffer 1 byte
* A<-data
* Cflag<-0:empty 1:read success
UARTTxRead
		bsr	UARTTxEmptyCheck	*check buffer empty
		bcc	UARTTxR00		*
		lda	UARTTxRPtr		*
		add	#UARTTxBuff		*
		tax				*
		lda	,X			*
		tax				*
		lda	UARTTxRPtr		*
		inca				*
		and	#$03			*
		sta	UARTTxRPtr		*
		txa				*
		sec				*set c flag
UARTTxR00	rts				*
*Rx write buffer 1 byte
* A<-data
* CFlag->0:success 1:failure
UARTRxWrite
		tax				*
		lda	UARTRxWPtr		*buffer check
		inca				*
		and	#$03			*
		cmp	UARTRxRPtr		*
		beq	UARTRxW00		*buffer full
		lda	UARTRxWPtr		*
		add	#UARTRxBuff		*
		sta	Work7			*
		lda	UARTRxWPtr		*
		inca				*
		and	#$03			*
		sta	UARTRxWPtr		*
		txa				*
		ldx	Work7			*
		sta	,X			*set data
		clc				*c flag clear
		rts				*
UARTRxW00	txa				*
		sec				*c flag set
		rts				*
*Rx read buffer 1 byte
* A<-data
* Cflag<-0:empty 1:read success
UARTRxRead
		lda	UARTRxRPtr		*check buffer empty
		cmp	UARTRxWPtr		*
		beq	UARTRxR00		*
		lda	UARTRxRPtr		*
		add	#UARTRxBuff		*
		tax				*
		lda	,X			*
		tax				*
		lda	UARTRxRPtr		*
		inca				*
		and	#$03			*
		sta	UARTRxRPtr		*
		txa				*
		sec				*set c flag
		rts				*
UARTRxR00	clc				*
		rts				*

*--------------------------------------------------------------------
*mini monitor
*--------------------------------------------------------------------
MonitorTask	jsr	THSwitch
*check swi
		tst	MonSWIFlag
		beq	MonitorCmdLine
*swi display
		clr	MonSWIFlag
Monswi00	lda	#Monswi01/256		*swi reg=> display out
		sta	MonWork+6		*
		lda	#Monswi01&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData09/256	*
		lda	#MonitorData09&$FF	*
		jmp	MonitorStrSend		*
Monswi01	lda	#Monswi02/256		*A= display out
		sta	MonWork+6		*
		lda	#Monswi02&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData05/256	*
		lda	#MonitorData05&$FF	*
		jmp	MonitorStrSend		*
Monswi02	lda	#Monswi03/256		*A reg value display out
		sta	MonWork+6		*
		lda	#Monswi03&$FF		*
		sta	MonWork+7		*
		ldx	#MonRegA		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
Monswi03	lda	#Monswi04/256		*X= display out
		sta	MonWork+6		*
		lda	#Monswi04&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData06/256	*
		lda	#MonitorData06&$FF	*
		jmp	MonitorStrSend		*
Monswi04	lda	#Monswi05/256		*X reg value display out
		sta	MonWork+6		*
		lda	#Monswi05&$FF		*
		sta	MonWork+7		*
		ldx	#MonRegX		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
Monswi05	lda	#$0d			*command line enter
		jsr	UARTTxWrite		*
		bcc	MonitorEnd		*
		jsr	THSwitch		*
		bra	Monswi05		*
*command line input
MonitorCmdLine	jsr	UARTRxRead		*check input
		bcc	MonEnd00		*
		sta	Work0			*
		cmp	#$0d			*enter
		beq	MonitorEnter		*
		cmp	#$0a			*enter
		beq	MonitorEnter		*
		cmp	#$08			*BS key
		beq	MonitorBS		*
		lda	MonInpCnt		*input buffer empty check
		cmp	#$08			*
		bmi	MonitorInBuff		*
		bra	MonEnd00		*
MonitorInBuff	lda	MonInpCnt		*
		add	#MonWork		*add input buffer
		tax				*
		lda	Work0			*
		sta	,X			*
		inc	MonInpCnt		*inc input counter
MonitorIn00	jsr	UARTTxWrite		*
		bcc	MonEnd00		*
		jsr	THSwitch		*
		bra	MonitorIn00		*
MonitorBS	lda	MonInpCnt		*check inpuit counter
		cmp	#$00			*
		bls	MonEnd00		*
		dec	MonInpCnt		*dec counter
		ldx	MonInpCnt		*
		clr	MonWork,X		*clear
		lda	#$08			*
MonitorBS00	jsr	UARTTxWrite		*
		bcc	MonitorBS01		*
		jsr	THSwitch		*
		bra	MonitorBS00		*
MonitorBS01	lda	#$20			*
MonitorBS02	jsr	UARTTxWrite		*
		bcc	MonitorBS03		*
		jsr	THSwitch		*
		bra	MonitorBS02		*
MonitorBS03	lda	#$08			*
MonitorBS04	jsr	UARTTxWrite		*
		bcc	MonEnd00		*
		jsr	THSwitch		*
		bra	MonitorBS04		*
MonitorEnd	clr	MonInpCnt		*input counter clear
		clr	MonWork			*
		clr	MonWork+1		*
		clr	MonWork+2		*
		clr	MonWork+3		*
		clr	MonWork+4		*
		clr	MonWork+5		*
		clr	MonWork+6		*
		clr	MonWork+7		*
		lda	#$3e			*prompt char display
		jsr	UARTTxWrite		*
		bcc	MonEnd00		*
		jsr	THSwitch		*
		bra	MonitorEnd		*
MonEnd00	jmp	ButtunProc		*
MonitorEnter	lda	#$0d			*command line enter
		jsr	UARTTxWrite		*
		bcc	Monitor00		*
		jsr	THSwitch		*
		bra	MonitorEnter		*
Monitor00	tst	MonInpCnt		*command check
		beq	MonitorEnd		*
		lda	MonWork			*branch command
		cmp	#$64			*d dump
		beq	MonDump
		cmp	#$74			*t thread
		beq	MonThread
		cmp	#$78			*x execute
		beq	MonJmp
		cmp	#$63			*c call
		beq	MonSubCall
		cmp	#$77			*w memory write
		beq	MonWrite
		cmp	#$68			*h help
		beq	MonHelpExec
		cmp	#$3f			*? help
		beq	MonHelpExec
		lda	#MonitorEnd/256		*command erroe display
		sta	MonWork+6		*
		lda	#MonitorEnd&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData03/256	*
		lda	#MonitorData03&$FF	*
		jmp	MonitorStrSend		*
MonDump		jmp	MonDumpExec		*jump
MonThread	jmp	MonThreadExec		*
MonJmp		jmp	MonJmpExec		*
MonSubCall	jmp	MonCallExec		*
MonWrite	jmp	MonWriteExec		*
*help message
MonHelpExec	lda	#MonHelp00/256		*help display out
		sta	MonWork+6		*
		lda	#MonHelp00&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorDataHlp/256	*
		lda	#MonitorDataHlp&$FF	*
		jmp	MonitorStrSend		*
MonHelp00	jmp	MonitorEnd		*
*execute
MonJmpExec	ldx	#MonWork+1		*16bit address
		jsr	Hex2Bin			*Hex to binary
		lda	#$cc			*jmp command set
		sta	MonWork			*
		lda	Work0			*
		sta	MonWork+1		*
		lda	Work1			*
		sta	MonWork+2		*
		jmp	MonWork			*
*sub routin call
MonCallExec	ldx	#MonWork+1		*16bit address
		jsr	Hex2Bin			*Hex to binary
		lda	#$cd			*jmp command set
		sta	MonWork			*
		lda	Work0			*
		sta	MonWork+1		*
		lda	Work1			*
		sta	MonWork+2		*
		lda	#$cc			*
		sta	MonWork+3		*
		lda	#MonitorEnd/256		*
		sta	MonWork+4		*
		lda	#MonitorEnd&$FF		*
		sta	MonWork+5		*
		jmp	MonWork			*
*Memory dump
MonDumpExec	lda	#MonDump00/256		*offset line display out
		sta	MonWork+6		*
		lda	#MonDump00&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData01/256	*
		lda	#MonitorData01&$FF	*
		jmp	MonitorStrSend		*
MonDump00	lda	#MonDump01/256		*separate line display out
		sta	MonWork+6		*
		lda	#MonDump01&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData02/256	*
		lda	#MonitorData02&$FF	*
		jmp	MonitorStrSend		*
MonDump01	clr	MonWork			*address count clear
		clr	MonWork+1		*
MonDump02	lda	#MonDump03/256		*
		sta	MonWork+6		*
		lda	#MonDump03&$FF		*
		sta	MonWork+7		*
		ldx	#MonWork		*address msb out
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*out
MonDump03	lda	#MonDump04/256		*
		sta	MonWork+6		*
		lda	#MonDump04&$FF		*
		sta	MonWork+7		*
		ldx	#MonWork+1		*address lsb out
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*out
MonDump04	lda	#MonDump05/256		*
		sta	MonWork+6		*
		lda	#MonDump05&$FF		*
		sta	MonWork+7		*
		lda	#$7c			*|send
		jmp	Monitor1Send		*
MonDump05	lda	#MonDump06/256		*
		sta	MonWork+6		*
		lda	#MonDump06&$FF		*
		sta	MonWork+7		*
		ldx	MonWork+1		*byte data out
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
MonDump06	inc	MonWork+1		*address inc
		lda	MonWork+1		*check 16 byte
		and	#$0f			*
		beq	MonDump07		*next line
		lda	#MonDump05/256		*space out
		sta	MonWork+6		*
		lda	#MonDump05&$FF		*
		sta	MonWork+7		*
		lda	#$20			*space send
		jmp	Monitor1Send		*
MonDump07	lda	#MonDump08/256		*cr out
		sta	MonWork+6		*
		lda	#MonDump08&$FF		*
		sta	MonWork+7		*
		lda	#$0d			*space send
		jmp	Monitor1Send		*
MonDump08	tst	MonWork+1		*term check
		beq	MonDump09		*display end
		jmp	MonDump02
MonDump09	jmp	MonitorEnd
*memory write
MonWriteExec	jsr	THSwitch
		ldx	#MonWork+1		*16bit address
		jsr	Hex2Bin			*Hex to binary
		lda	Work1			*
		sta	Work7			*
		jsr	Hex2Bin			*8bit data Hex to binary
		ldx	Work7			*
		lda	Work1			*
		sta	,X			*
		jmp	MonitorEnd		*
*thread list display
MonThreadExec	jsr	THSwitch
		clr	MonGWork+1		*clear thread count
		lda	#THContext0		*thread context work pointer
		sta	MonGWork		*
MonTh00		lda	#MonTh01/256		*message display out
		sta	MonWork+6		*
		lda	#MonTh01&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData04/256	*
		lda	#MonitorData04&$FF	*
		jmp	MonitorStrSend		*
MonTh01		lda	#MonTh02/256		*thread number display out
		sta	MonWork+6		*
		lda	#MonTh02&$FF		*
		sta	MonWork+7		*
		ldx	#MonGWork+1		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
MonTh02		lda	#MonTh03/256		*A= display out
		sta	MonWork+6		*
		lda	#MonTh03&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData05/256	*
		lda	#MonitorData05&$FF	*
		jmp	MonitorStrSend		*
MonTh03		lda	#MonTh04/256		*A reg value display out
		sta	MonWork+6		*
		lda	#MonTh04&$FF		*
		sta	MonWork+7		*
		ldx	MonGWork		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
MonTh04		inc	MonGWork
		lda	#MonTh05/256		*X= display out
		sta	MonWork+6		*
		lda	#MonTh05&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData06/256	*
		lda	#MonitorData06&$FF	*
		jmp	MonitorStrSend		*
MonTh05		lda	#MonTh06/256		*X reg value display out
		sta	MonWork+6		*
		lda	#MonTh06&$FF		*
		sta	MonWork+7		*
		ldx	MonGWork		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
MonTh06		inc	MonGWork
		lda	#MonTh07/256		*PC= display out
		sta	MonWork+6		*
		lda	#MonTh07&$FF		*
		sta	MonWork+7		*
		ldx	#MonitorData07/256	*
		lda	#MonitorData07&$FF	*
		jmp	MonitorStrSend		*
MonTh07		lda	#MonTh08/256		*PCH reg value display out
		sta	MonWork+6		*
		lda	#MonTh08&$FF		*
		sta	MonWork+7		*
		ldx	MonGWork		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
MonTh08		inc	MonGWork
		lda	#MonTh09/256		*PCL reg value display out
		sta	MonWork+6		*
		lda	#MonTh09&$FF		*
		sta	MonWork+7		*
		ldx	MonGWork		*
		jsr	Bin2Ascii		*
		jmp	Monitor2Send		*
MonTh09		lda	#MonTh10/256		*CR display out
		sta	MonWork+6		*
		lda	#MonTh10&$FF		*
		sta	MonWork+7		*
		lda	#$0d			*
		jmp	Monitor1Send		*
MonTh10		inc	MonGWork		*
		inc	MonGWork+1		*thread count inc
		lda	MonGWork+1		*loop count
		cmp	#$04			*end check
		beq	MonTh11			*go end
		jmp	MonTh00
MonTh11		jmp	MonitorEnd
*monitor swi
MonitorSWI	sta	MonRegA
		stx	MonRegX
		inc	MonSWIFlag
		rti
*monitor initarize
MonitorIni	
MonBuffClear	clr	MonInpCnt
		clr	MonWork
		clr	MonWork+1
		clr	MonWork+2
		clr	MonWork+3
		clr	MonWork+4
		clr	MonWork+5
		clr	MonWork+6
		clr	MonWork+7
		clr	MonSWIFlag
		rts
*message string
MonitorMes00	lda	#22
MonStartupWait	deca
		beq	MonitorStartMes
		jsr	THSwitch
		bra	MonStartupWait
MonitorStartMes	lda	#MonitorEnd/256
		sta	MonWork+6
		lda	#MonitorEnd&$FF
		sta	MonWork+7
		ldx	#MonitorData00/256
		lda	#MonitorData00&$FF
		jmp	MonitorStrSend
*1byte send	
* A<-chr code
* [Work6:Work7] return address
Monitor1Send
		stx	MonWork+4
		sta	MonWork+5
Mon1Send00	lda	MonWork+5
		jsr	UARTTxWrite
		bcc	Mon1Send01
		jsr	THSwitch
		bra	Mon1Send00
Mon1Send01	lda	MonWork+5
		ldx	#$cc
		stx	MonWork+5
		ldx	MonWork+4
		jmp	MonWork+5
*2byte send
* x<-MSB char
* A<-LSB char
* [Work6:Work7] return address
Monitor2Send	stx	MonWork+4
		sta	MonWork+5
Mon2Send00	lda	MonWork+4
		jsr	UARTTxWrite
		bcc	Mon2Send01
		jsr	THSwitch
		bra	Mon2Send00
Mon2Send01	lda	MonWork+5
Mon2Send02	jsr	UARTTxWrite
		bcc	Mon2Send03
		jsr	THSwitch
		bra	Mon2Send01
Mon2Send03	lda	MonWork+5
		ldx	#$cc
		stx	MonWork+5
		ldx	MonWork+4
		jmp	MonWork+5
*fix message send
* [X:A] string top address
* [Work6:Work7] return address
MonitorStrSend	stx	MonWork+1		*ram write lda aaaa,x
		sta	MonWork+2		*
		lda	#$d6			*
		sta	MonWork			*
		lda	#$81			*ram write rts
		sta	MonWork+3		*
		clr	MonPerReg		*offset counter clear
MonitorM00	ldx	MonPerReg		*load offset
		jsr	MonWork			*lda aaaa,X	exec
		beq	MonitorMessEnd		*string terminate detect
MonitorM01	jsr	UARTTxWrite		*send character
		bcc	MonitorM02		*send success
		jsr	THSwitch		*thread switch
		bra	MonitorM00		*
MonitorM02	inc	MonPerReg		*next data
		bra	MonitorM00		*
MonitorMessEnd	lda	#$cc
		sta	Work5
		lda	MonWork+6
		sta	Work6
		lda	MonWork+7
		sta	Work7
		jsr	MonBuffClear		*
		jmp	Work5			*
MonitorData00	fcb	$0d
		fcb	'M,'i,'n,'i,'M,'o,'n,'i,'t,'o,'r,' ,'V,'e,'r,'.,'1,'.,'0
		fcb	' ,'(,'c,'),'c,'o,'m,'o,'n,'e,'k,'o,' ,'2,'0,'2,'2,$0d,$00
MonitorData01	fcb	$0d
		fcb	'A,'D,'D,'R,'|,'+,'0,' ,'+,'1,' ,'+,'2
		fcb	' ,'+,'3,' ,'+,'4,' ,'+,'5,' ,'+,'6,' ,'+
		fcb	'7,' ,'+,'8,' ,'+,'9,' ,'+,'A,' ,'+,'B
		fcb	' ,'+,'C,' ,'+,'D,' ,'+,'E,' ,'+,'F,'|,$0d,$00
MonitorData02	fcb	'-,'-,'-,'-,'+,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-
		fcb	'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-
		fcb	'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-,'-
		fcb	'-,'-,'-,'-,'+,$0d,$00
MonitorData03	fcb	'I,'n,'v,'a,'l,'i,'d,' ,'c,'o,'m,'m,'a,'n,'d,$0d,$00
MonitorData04	fcb	'T,'h,'r,'e,'a,'d,' ,':,$00
MonitorData05	fcb	' ,'A,'=,$00
MonitorData06	fcb	' ,'X,'=,$00
MonitorData07	fcb	' ,'P,'C,'=,$00
MonitorData08	fcb	' ,'C,'C,'=,$00
MonitorData09	fcb	'S,'W,'I,' ,'R,'E,'G,' ,'=,'>,$00
MonitorDataHlp	fcb	'C,'o,'m,'m,'a,'n,'d,' ,'l,'i,'s,'t,$0d
		fcb	'd,' ,'M,'e,'m,'o,'r,'y,' ,'d,'u,'m,'p,' ,'(
		fcb	'f,'i,'x,' ,'$,'0,'0,'0,'0,'-,'$,'0,'0,'F,'F,'),$0d
		fcb	't,' ,'T,'h,'r,'e,'a,'d,' ,'l,'i,'s,'t,$0d
		fcb	'w,'[,'a,'d,'d,'r,' ,'0,'0,'-,'F,'F,'],' ,'[
		fcb	'd,'a,'t,'a,'], 'M,'e,'m,'o,'r,'y,' ,'w,'r,'i,'t,'e,$0d
		fcb	'x,'[,'a,'d,'d,'r,'0,'0,'0,'0,'-,'F,'F,'F,'F
		fcb	'],' ,'e,'x,'e,'c,'u,'t,'e,$0d
		fcb	'c,'[,'a,'d,'d,'r,'0,'0,'0,'0,'-,'F,'F,'F,'F
		fcb	'],' ,'s,'u,'b,'r,'o,'u,'t,'i,'n,' ,'c,'a,'l,'l,$0d
		fcb	'R,'e,'g,'i,'s,'t,'e,'r,' ,'d,'i,'s,'p,'l,'a
		fcb	'y,' ,'b,'y,' ,'S,'W,'I,$0d		
		fcb	$00


*--------------------------------------------------------------------
*--------------------------------------------------------------------
*vector table
		org	VECTOR_TABLE
TimerIRQVect	fdb	TIMER_IRQ
INTIRQVect	fdb	INT_IRQ
SWIVect		fdb	SWI_IRQ
ResetVect	fdb	START

