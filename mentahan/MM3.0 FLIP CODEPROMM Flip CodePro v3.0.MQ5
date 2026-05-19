//+------------------------------------------------------------------------------+//

//)                                                                              (//

//)                                                                              (//

//)                                                                              (//

//)   https://fxprosystems.com/               Copyright 2025 | FXProSystems.com  (//

//+------------------------------------------------------------------------------+//

#property copyright   "Copyright 2025 | FXProSystems.com"

#property link        "https://fxprosystems.com/"

#property description ""

#property version     "1.0"

#property strict

#include <Trade\Trade.mqh>

CTrade trade;



/************************************************************************************************************************/

// +------------------------------------------------------------------------------------------------------------------+ //

// |                       INPUT PARAMETERS, GLOBAL VARIABLES, CONSTANTS, IMPORTS and INCLUDES                        | //

// |                      System and Custom variables and other definitions used in the project                       | //

// +------------------------------------------------------------------------------------------------------------------+ //

/************************************************************************************************************************/



input bool EnableTrailingStop = true; // Enable trailing stop

input double TrailingStep = 5; // Trailing step in pips

input double TrailingStop = 5; // Trailing stop distance in pips

input double DefaultSLPips = 10;      // Default SL (pips) for general pairs

input double XAUUSD_SLPoints = 10;    // SL (points) for XAUUSD



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// System constants (project settings) //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

//--

#define PROJECT_ID "mt5-3059"

//--

// Point Format Rules

#define POINT_FORMAT_RULES "0.001=0.01,0.00001=0.0001,0.000001=0.0001" // this is deserialized in a special function later

#define ENABLE_SPREAD_METER true

#define ENABLE_STATUS true

#define ENABLE_TEST_INDICATORS true

//--

// Events On/Off

#define ENABLE_EVENT_TICK 1 // enable "Tick" event

#define ENABLE_EVENT_TRADE 0 // enable "Trade" event

#define ENABLE_EVENT_TIMER 0 // enable "Timer" event

//--

// Virtual Stops

#define VIRTUAL_STOPS_ENABLED 0 // enable virtual stops

#define VIRTUAL_STOPS_TIMEOUT 0 // virtual stops timeout

#define USE_EMERGENCY_STOPS "no" // "yes" to use emergency (hard stops) when virtual stops are in use. "always" to use EMERGENCY_STOPS_ADD as emergency stops when there is no virtual stop.

#define EMERGENCY_STOPS_REL 0 // use 0 to disable hard stops when virtual stops are enabled. Use a value >=0 to automatically set hard stops with virtual. Example: if 2 is used, then hard stops will be 2 times bigger than virtual ones.

#define EMERGENCY_STOPS_ADD 0 // add pips to relative size of emergency stops (hard stops)

//--

// Settings for events

#define ON_TIMER_PERIOD 60 // Timer event period (in seconds)



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// System constants (predefined constants) //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

//--

#define TLOBJPROP_TIME1 801

#define OBJPROP_TL_PRICE_BY_SHIFT 802

#define OBJPROP_TL_SHIFT_BY_PRICE 803

#define OBJPROP_FIBOVALUE 804

#define OBJPROP_FIBOPRICEVALUE 805

#define OBJPROP_FIRSTLEVEL 806

#define OBJPROP_TIME1 807

#define OBJPROP_TIME2 808

#define OBJPROP_TIME3 809

#define OBJPROP_PRICE1 810

#define OBJPROP_PRICE2 811

#define OBJPROP_PRICE3 812

#define OBJPROP_BARSHIFT1 813

#define OBJPROP_BARSHIFT2 814

#define OBJPROP_BARSHIFT3 815

#define SEL_CURRENT 0

#define SEL_INITIAL 1



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// Enumerations, Imports, Constants, Variables //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//













//--

// Constants (Input Parameters)

input int MagicStart = 4953; // Magic Number, kind of...

class c

{

		public:

	static int MagicStart;

};

int c::MagicStart;





//--

// Variables (Global Variables)

class v

{

		public:

};







//--

// Externs (Global Variables)

input double inp11_VolumeSize = 0.01;

input double inp12_VolumeSize = 0.01;

input double inp17_VolumeSize = 0.01;

input double inp18_VolumeSize = 0.01;

input double inp101_VolumeSize = 0.01;

input double inp102_VolumeSize = 0.01;

input double inp103_VolumeSize = 0.01;

input double inp104_VolumeSize = 0.01;

input double inp105_VolumeSize = 0.01;

input double inp106_VolumeSize = 0.01;

input double inp107_VolumeSize = 0.01;

input double inp108_VolumeSize = 0.01;

input double inp111_VolumeSize = 0.01;

input double inp112_VolumeSize = 0.01;

input double inp113_VolumeSize = 0.01;

input double inp114_VolumeSize = 0.01;

input double inp115_VolumeSize = 0.01;

input double inp116_VolumeSize = 0.01;

input double inp117_VolumeSize = 0.01;

input double inp118_VolumeSize = 0.01; 





class _externs

{

		public:

	static double inp11_VolumeSize;

	static double inp12_VolumeSize;

	static double inp17_VolumeSize;

	static double inp18_VolumeSize;

	static double inp101_VolumeSize;

   static double inp102_VolumeSize;

   static double inp103_VolumeSize;

   static double inp104_VolumeSize;

   static double inp105_VolumeSize;

   static double inp106_VolumeSize;

   static double inp107_VolumeSize;

   static double inp108_VolumeSize;

   static double inp111_VolumeSize;

   static double inp112_VolumeSize;

   static double inp113_VolumeSize;

   static double inp114_VolumeSize;

   static double inp115_VolumeSize;

   static double inp116_VolumeSize;

   static double inp117_VolumeSize;

   static double inp118_VolumeSize;

   

	

};



double _externs::inp11_VolumeSize;

double _externs::inp12_VolumeSize;

double _externs::inp17_VolumeSize;

double _externs::inp18_VolumeSize;

double _externs::inp101_VolumeSize;

double _externs::inp102_VolumeSize;

double _externs::inp103_VolumeSize;

double _externs::inp104_VolumeSize;

double _externs::inp105_VolumeSize;

double _externs::inp106_VolumeSize;

double _externs::inp107_VolumeSize;

double _externs::inp108_VolumeSize;

double _externs::inp111_VolumeSize;

double _externs::inp112_VolumeSize;

double _externs::inp113_VolumeSize;

double _externs::inp114_VolumeSize;

double _externs::inp115_VolumeSize;

double _externs::inp116_VolumeSize;

double _externs::inp117_VolumeSize;

double _externs::inp118_VolumeSize;







//VVVVVVVVVVVVVVVVVVVVVVVVV//

// System global variables //

//^^^^^^^^^^^^^^^^^^^^^^^^^//

//--

// Blocks Lookup Functions

string fxdBlocksLookupTable[];



int FXD_CURRENT_FUNCTION_ID = 0;

double FXD_MILS_INIT_END    = 0;

int FXD_TICKS_FROM_START    = 0;

int FXD_MORE_SHIFT          = 0;

bool FXD_DRAW_SPREAD_INFO   = false;

bool FXD_FIRST_TICK_PASSED  = false;

bool FXD_BREAK              = false;

bool FXD_CONTINUE           = false;

bool USE_VIRTUAL_STOPS = VIRTUAL_STOPS_ENABLED;

string FXD_CURRENT_SYMBOL   = "";

int FXD_BLOCKS_COUNT        = 12;

datetime FXD_TICKSKIP_UNTIL = 0;



int FXD_ICUSTOM_HANDLES_IDS[]; // only used in MQL5

string FXD_ICUSTOM_HANDLES_KEYS[]; // only used in MQL5



//- for use in OnChart() event

struct fxd_onchart

{

	int id;

	long lparam;

	double dparam;

	string sparam;

};

fxd_onchart FXD_ONCHART;



/************************************************************************************************************************/

// +------------------------------------------------------------------------------------------------------------------+ //

// |                                                 EVENT FUNCTIONS                                                  | //

// |                           These are the main functions that controls the whole project                           | //

// +------------------------------------------------------------------------------------------------------------------+ //

/************************************************************************************************************************/



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// This function is executed once when the program starts //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

int OnInit()

{



	// Initiate Constants

	c::MagicStart = MagicStart;









	// Initiate Externs

	_externs::inp11_VolumeSize = inp11_VolumeSize;

	_externs::inp12_VolumeSize = inp12_VolumeSize;

	_externs::inp17_VolumeSize = inp17_VolumeSize;

	_externs::inp18_VolumeSize = inp18_VolumeSize;

	

	_externs::inp101_VolumeSize = inp101_VolumeSize;

	_externs::inp102_VolumeSize = inp102_VolumeSize;

	_externs::inp103_VolumeSize = inp103_VolumeSize;

	_externs::inp104_VolumeSize = inp104_VolumeSize;

	_externs::inp105_VolumeSize = inp105_VolumeSize;

	_externs::inp106_VolumeSize = inp106_VolumeSize;

	_externs::inp107_VolumeSize = inp107_VolumeSize;

	_externs::inp108_VolumeSize = inp108_VolumeSize;

	_externs::inp111_VolumeSize = inp111_VolumeSize;

	_externs::inp112_VolumeSize = inp112_VolumeSize;

	_externs::inp113_VolumeSize = inp113_VolumeSize;

	_externs::inp114_VolumeSize = inp114_VolumeSize;

	_externs::inp115_VolumeSize = inp115_VolumeSize;

	_externs::inp116_VolumeSize = inp116_VolumeSize;

	_externs::inp117_VolumeSize = inp117_VolumeSize;

	_externs::inp118_VolumeSize = inp118_VolumeSize;







	// do or do not not initilialize on reload

	if (UninitializeReason() != 0)

	{

		if (UninitializeReason() == REASON_CHARTCHANGE)

		{

			// if the symbol is the same, do not reload, otherwise continue below

			if (FXD_CURRENT_SYMBOL == Symbol()) {return INIT_SUCCEEDED;}

		}

		else

		{

			return INIT_SUCCEEDED;

		}

	}

	FXD_CURRENT_SYMBOL = Symbol();



	CurrentSymbol(FXD_CURRENT_SYMBOL); // CurrentSymbol() has internal memory that should be set from here when the symboll is changed

	CurrentTimeframe(PERIOD_CURRENT);











	Comment("");

	for (int i=ObjectsTotal(ChartID()); i>=0; i--)

	{

		string name = ObjectName(ChartID(), i);

		if (StringSubstr(name,0,8) == "fxd_cmnt") {ObjectDelete(ChartID(), name);}

	}

	ChartRedraw();







	//-- disable virtual stops in optimization, because graphical objects does not work

	// http://docs.mql4.com/runtime/testing

	if (MQLInfoInteger(MQL_OPTIMIZATION)) {

		USE_VIRTUAL_STOPS = false;

	}



	//-- set initial local and server time

	TimeAtStart("set");



	//-- set initial balance

	AccountBalanceAtStart();



	//-- draw the initial spread info meter

	if (ENABLE_SPREAD_METER == false) {

		FXD_DRAW_SPREAD_INFO = false;

	}

	else {

		FXD_DRAW_SPREAD_INFO = !(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE));

	}

	if (FXD_DRAW_SPREAD_INFO) DrawSpreadInfo();



	//-- draw initial status

	if (ENABLE_STATUS) DrawStatus("waiting for tick...");



	//-- draw indicators after test

	TesterHideIndicators(!ENABLE_TEST_INDICATORS);



	if (ENABLE_EVENT_TIMER) {

		OnTimerSet(ON_TIMER_PERIOD);

	}





	//-- Initialize blocks classes

	ArrayResize(_blocks_, 46);



	_blocks_[0] = new Block0();

	_blocks_[1] = new Block1();

	_blocks_[2] = new Block2();

	_blocks_[3] = new Block3();

	_blocks_[4] = new Block4();

	_blocks_[5] = new Block5();

	_blocks_[6] = new Block6();

	_blocks_[7] = new Block7();

	_blocks_[8] = new Block8();

	_blocks_[9] = new Block9();

	_blocks_[10] = new Block10();

	_blocks_[11] = new Block11();

	_blocks_[12] = new Block12();

	_blocks_[13] = new Block13();

	_blocks_[14] = new Block14();

	_blocks_[15] = new Block15();

	_blocks_[16] = new Block16();

	_blocks_[17] = new Block17();

	_blocks_[18] = new Block18();

	_blocks_[19] = new Block19();

	_blocks_[20] = new Block20();

	_blocks_[21] = new Block21();

	_blocks_[22] = new Block22();

	_blocks_[23] = new Block23();

	_blocks_[24] = new Block24();

	_blocks_[25] = new Block25();

	_blocks_[26] = new Block26();

	_blocks_[27] = new Block27();

	_blocks_[28] = new Block28();

	_blocks_[29] = new Block29();

	_blocks_[30] = new Block30();

	_blocks_[31] = new Block31();

	_blocks_[32] = new Block32();

	_blocks_[33] = new Block33();

	_blocks_[34] = new Block34();

	_blocks_[35] = new Block35();

	_blocks_[36] = new Block36();

	_blocks_[37] = new Block37();

	_blocks_[38] = new Block38();

	_blocks_[39] = new Block39();

	_blocks_[40] = new Block40();

	_blocks_[41] = new Block41();

	_blocks_[42] = new Block42();

	_blocks_[43] = new Block43();

	_blocks_[44] = new Block44();

	_blocks_[45] = new Block45();



	// fill the lookup table

	ArrayResize(fxdBlocksLookupTable, ArraySize(_blocks_));

	for (int i=0; i<ArraySize(_blocks_); i++)

	{

		fxdBlocksLookupTable[i] = _blocks_[i].__block_user_number;

	}



	// fill the list of inbound blocks for each BlockCalls instance

	for (int i=0; i<ArraySize(_blocks_); i++)

	{

		_blocks_[i].__announceThisBlock();

	}



	// List of initially disabled blocks

	int disabled_blocks_list[] = {};

	for (int l = 0; l < ArraySize(disabled_blocks_list); l++) {

		_blocks_[disabled_blocks_list[l]].__disabled = true;

	}







	FXD_MILS_INIT_END     = (double)GetTickCount();

	FXD_FIRST_TICK_PASSED = false; // reset is needed when changing inputs



	return(INIT_SUCCEEDED);

}



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// This function is executed on every incoming tick //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

void OnTick()

{

	FXD_TICKS_FROM_START++;



	if (ENABLE_STATUS && FXD_TICKS_FROM_START == 1) DrawStatus("working");



	//-- special system actions

	if (FXD_DRAW_SPREAD_INFO) DrawSpreadInfo();

	TicksData(""); // Collect ticks (if needed)

	TicksPerSecond(false, true); // Collect ticks per second

	if (USE_VIRTUAL_STOPS) {VirtualStopsDriver();}



	if (false) ExpirationWorker * expirationDummy = new ExpirationWorker();

	expirationWorker.Run();



	OCODriver(); // Check and close OCO orders



	// skip ticks

	if (TimeLocal() < FXD_TICKSKIP_UNTIL) {return;}



	//-- run blocks

	int blocks_to_run[] = {0,1};

	for (int i=0; i<ArraySize(blocks_to_run); i++) {

		_blocks_[blocks_to_run[i]].run();

	}

	

	if (EnableTrailingStop) CheckTrailingStop(FXD_CURRENT_SYMBOL, MagicStart);





	return;

}



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// This function is executed on trade events - open, close, modify //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

void OnTrade()

{

	// This is needed so that the OnTradeEventDetector class is added into the code

	if (false) OnTradeEventDetector * dummy = new OnTradeEventDetector();



}





//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// This function is executed on a period basis //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

void OnTimer()

{



}





//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// This function is executed when chart event happens //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

void OnChartEvent(

	const int id,         // Event ID

	const long& lparam,   // Parameter of type long event

	const double& dparam, // Parameter of type double event

	const string& sparam  // Parameter of type string events

)

{

	//-- write parameter to the system global variables

	FXD_ONCHART.id     = id;

	FXD_ONCHART.lparam = lparam;

	FXD_ONCHART.dparam = dparam;

	FXD_ONCHART.sparam = sparam;





	return;

}



//VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//

// This function is executed once when the program ends //

//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^//

void OnDeinit(const int reason)

{

	int reson = UninitializeReason();

	if (reson == REASON_CHARTCHANGE || reson == REASON_PARAMETERS || reason == REASON_TEMPLATE || reason == REASON_ACCOUNT) {return;}



	//-- if Timer was set, kill it here

	EventKillTimer();



	if (ENABLE_STATUS) DrawStatus("stopped");

	if (ENABLE_SPREAD_METER) DrawSpreadInfo();

	ChartSetString(0, CHART_COMMENT, "");







	if (MQLInfoInteger(MQL_TESTER)) {

		Print("Backtested in "+DoubleToString((GetTickCount()-FXD_MILS_INIT_END)/1000, 2)+" seconds");

		double tc = GetTickCount()-FXD_MILS_INIT_END;

		if (tc > 0)

		{

			Print("Average ticks per second: "+DoubleToString(FXD_TICKS_FROM_START/tc, 0));

		}

	}



	if (MQLInfoInteger(MQL_PROGRAM_TYPE) == PROGRAM_EXPERT)

	{

		switch(UninitializeReason())

		{

			case REASON_PROGRAM		: Print("Expert Advisor self terminated"); break;

			case REASON_REMOVE		: Print("Expert Advisor removed from the chart"); break;

			case REASON_RECOMPILE	: Print("Expert Advisor has been recompiled"); break;

			case REASON_CHARTCHANGE	: Print("Symbol or chart period has been changed"); break;

			case REASON_CHARTCLOSE	: Print("Chart has been closed"); break;

			case REASON_PARAMETERS	: Print("Input parameters have been changed by a user"); break;

			case REASON_ACCOUNT		: Print("Another account has been activated or reconnection to the trade server has occurred due to changes in the account settings"); break;

			case REASON_TEMPLATE		: Print("A new template has been applied"); break;

			case REASON_INITFAILED	: Print("OnInit() handler has returned a nonzero value"); break;

			case REASON_CLOSE			: Print("Terminal has been closed"); break;

		}

	}



	// delete dynamic pointers

	for (int i=0; i<ArraySize(_blocks_); i++)

	{

		delete _blocks_[i];

		_blocks_[i] = NULL;

	}

	ArrayResize(_blocks_, 0);



	return;

}



/************************************************************************************************************************/

// +------------------------------------------------------------------------------------------------------------------+ //

// |                                             Classes of blocks                                                    | //

// |              Classes that contain the actual code of the blocks and their input parameters as well               | //

// +------------------------------------------------------------------------------------------------------------------+ //

/************************************************************************************************************************/



/**

	The base class for all block calls

   */

class BlockCalls

{

	public:

		bool __disabled; // whether or not the block is disabled



		string __block_user_number;

      int __block_number;

		int __block_waiting;

		int __parent_number;

		int __inbound_blocks[];

		int __outbound_blocks[];



		void __addInboundBlock(int id = 0) {

			int size = ArraySize(__inbound_blocks);

			for (int i = 0; i < size; i++) {

				if (__inbound_blocks[i] == id) {

					return;

				}

			}

			ArrayResize(__inbound_blocks, size + 1);

			__inbound_blocks[size] = id;

		}



		void BlockCalls() {

			__disabled          = false;

			__block_user_number = "";

			__block_number      = 0;

			__block_waiting     = 0;

			__parent_number     = 0;

		}



		/**

		   Announce this block to the list of inbound connections of all the blocks to which this block is connected to

		   */

		void __announceThisBlock()

		{

		   // add the current block number to the list of inbound blocks

		   // for each outbound block that is provided

			for (int i = 0; i < ArraySize(__outbound_blocks); i++)

			{

				int block = __outbound_blocks[i]; // outbound block number

				int size  = ArraySize(_blocks_[block].__inbound_blocks); // the size of its inbound list



				// skip if the current block was already added

				for (int j = 0; j < size; j++) {

					if (_blocks_[block].__inbound_blocks[j] == __block_number)

					{

						return;

					}

				}



				// add the current block number to the list of inbound blocks of the other block

				ArrayResize(_blocks_[block].__inbound_blocks, size + 1);

				_blocks_[block].__inbound_blocks[size] = __block_number;

			}

		}



		// this is here, because it is used in the "run" function

		virtual void _execute_() = 0;



		/**

			In the derived class this method should be used to set dynamic parameters or other stuff before the main execute.

			This method is automatically called within the main "run" method below, before the execution of the main class.

			*/

		virtual void _beforeExecute_() {return;};

		bool _beforeExecuteEnabled; // for speed



		/**

			Same as _beforeExecute_, but to work after the execute method.

			*/

		virtual void _afterExecute_() {return;};

		bool _afterExecuteEnabled; // for speed



		/**

			This is the method that is used to run the block

			*/

		virtual void run(int _parent_=0) {

			__parent_number = _parent_;

			if (__disabled || FXD_BREAK) {return;}

			FXD_CURRENT_FUNCTION_ID = __block_number;



			if (_beforeExecuteEnabled) {_beforeExecute_();}

			_execute_();

			if (_afterExecuteEnabled) {_afterExecute_();}



			if (__block_waiting && FXD_CURRENT_FUNCTION_ID == __block_number) {fxdWait.Accumulate(FXD_CURRENT_FUNCTION_ID);}

		}

};



BlockCalls *_blocks_[];





// "No position" model

template<typename T1,typename T2,typename T3,typename T4,typename T5>

class MDL_NoOpenedOrders: public BlockCalls

{

	public: /* Input Parameters */

	T1 GroupMode;

	T2 Group;

	T3 SymbolMode;

	T4 Symbol;

	T5 BuysOrSells;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDL_NoOpenedOrders()

	{

		GroupMode = (string)"group";

		Group = (string)"";

		SymbolMode = (string)"symbol";

		Symbol = (string)CurrentSymbol();

		BuysOrSells = (string)"both";

	}



	public: /* The main method */

	virtual void _execute_()

	{

		bool exist = false;

		

		for (int index = TradesTotal()-1; index >= 0; index--)

		{

			if (TradeSelectByIndex(index, GroupMode, Group, SymbolMode, Symbol, BuysOrSells))

			{

				exist = true;

				break;

			}

		}

		

		if (exist == false) {_callback_(1);} else {_callback_(0);}

	}

};



// "If position" model

template<typename T1,typename T2,typename T3,typename T4,typename T5>

class MDL_IfOpenedOrders: public BlockCalls

{

	public: /* Input Parameters */

	T1 GroupMode;

	T2 Group;

	T3 SymbolMode;

	T4 Symbol;

	T5 BuysOrSells;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDL_IfOpenedOrders()

	{

		GroupMode = (string)"group";

		Group = (string)"";

		SymbolMode = (string)"symbol";

		Symbol = (string)CurrentSymbol();

		BuysOrSells = (string)"both";

	}



	public: /* The main method */

	virtual void _execute_()

	{

		bool exist = false;

		

		for (int index = TradesTotal()-1; index >= 0; index--)

		{

			if (TradeSelectByIndex(index, GroupMode, Group, SymbolMode, Symbol, BuysOrSells))

			{

				exist = true;

				break;

			}

		}

		

		if (exist == true) {_callback_(1);} else {_callback_(0);}

	}

};



// "Condition" model

template<typename T1,typename _T1_,typename T2,typename T3,typename _T3_,typename T4>

class MDL_Condition: public BlockCalls

{

	public: /* Input Parameters */

	T1 Lo; virtual _T1_ _Lo_(){return(_T1_)0;}

	T2 compare;

	T3 Ro; virtual _T3_ _Ro_(){return(_T3_)0;}

	T4 crosswidth;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDL_Condition()

	{

		compare = (string)">";

		crosswidth = (int)1;

	}



	public: /* The main method */

	virtual void _execute_()

	{

		bool output1 = false, output2 = false; // output 1 and output 2

		int crossover = 0;

		

		if (compare == "x>" || compare == "x<") {crossover = 1;}

		

		for (int i = 0; i <= crossover; i++)

		{

			// i=0 - normal pass, i=1 - crossover pass

		

			// Left operand of the condition

			FXD_MORE_SHIFT = i * crosswidth;

			_T1_ lo = _Lo_();

			if (MathAbs(lo) == EMPTY_VALUE) {return;}

		

			// Right operand of the condition

			FXD_MORE_SHIFT = i * crosswidth;

			_T3_ ro = _Ro_();

			if (MathAbs(ro) == EMPTY_VALUE) {return;}

		

			// Conditions

			if (CompareValues(compare, lo, ro))

			{

				if (i == 0)

				{

					output1 = true;

				}

			}

			else

			{

				if (i == 0)

				{

					output2 = true;

				}

				else

				{

					output2 = false;

				}

			}

		

			if (crossover == 1)

			{

				if (CompareValues(compare, ro, lo))

				{

					if (i == 0)

					{

						output2 = true;

					}

				}

				else

				{

					if (i == 1)

					{

						output1 = false;

					}

				}

			}

		}

		

		FXD_MORE_SHIFT = 0; // reset

		

			  if (output1 == true) {_callback_(1);}

		else if (output2 == true) {_callback_(0);}

	}

};



// "Buy now" model

template<typename T1,typename T2,typename T3,typename T4,typename T5,typename T6,typename T7,typename T8,typename T9,typename _T9_,typename T10,typename T11,typename T12,typename T13,typename T14,typename T15,typename T16,typename T17,typename T18,typename T19,typename T20,typename T21,typename T22,typename T23,typename T24,typename T25,typename T26,typename T27,typename T28,typename T29,typename T30,typename T31,typename T32,typename T33,typename T34,typename T35,typename T36,typename T37,typename _T37_,typename T38,typename _T38_,typename T39,typename _T39_,typename T40,typename T41,typename T42,typename T43,typename T44,typename _T44_,typename T45,typename _T45_,typename T46,typename _T46_,typename T47,typename T48,typename T49,typename T50,typename T51,typename _T51_,typename T52,typename T53,typename T54>

class MDL_BuyNow: public BlockCalls

{

	public: /* Input Parameters */

	T1 Group;

	T2 Symbol;

	T3 VolumeMode;

	T4 VolumeSize;

	T5 VolumeSizeRisk;

	T6 VolumeRisk;

	T7 VolumePercent;

	T8 VolumeBlockPercent;

	T9 dVolumeSize; virtual _T9_ _dVolumeSize_(){return(_T9_)0;}

	T10 FixedRatioUnitSize;

	T11 FixedRatioDelta;

	T12 mmTradesPool;

	T13 mmMgInitialLots;

	T14 mmMgMultiplyOnLoss;

	T15 mmMgMultiplyOnProfit;

	T16 mmMgAddLotsOnLoss;

	T17 mmMgAddLotsOnProfit;

	T18 mmMgResetOnLoss;

	T19 mmMgResetOnProfit;

	T20 mm1326InitialLots;

	T21 mm1326Reverse;

	T22 mmFiboInitialLots;

	T23 mmDalembertInitialLots;

	T24 mmDalembertReverse;

	T25 mmLabouchereInitialLots;

	T26 mmLabouchereList;

	T27 mmLabouchereReverse;

	T28 mmSeqBaseLots;

	T29 mmSeqOnLoss;

	T30 mmSeqOnProfit;

	T31 mmSeqReverse;

	T32 VolumeUpperLimit;

	T33 StopLossMode;

	T34 StopLossPips;

	T35 StopLossPercentPrice;

	T36 StopLossPercentTP;

	T37 dlStopLoss; virtual _T37_ _dlStopLoss_(){return(_T37_)0;}

	T38 dpStopLoss; virtual _T38_ _dpStopLoss_(){return(_T38_)0;}

	T39 ddStopLoss; virtual _T39_ _ddStopLoss_(){return(_T39_)0;}

	T40 TakeProfitMode;

	T41 TakeProfitPips;

	T42 TakeProfitPercentPrice;

	T43 TakeProfitPercentSL;

	T44 dlTakeProfit; virtual _T44_ _dlTakeProfit_(){return(_T44_)0;}

	T45 dpTakeProfit; virtual _T45_ _dpTakeProfit_(){return(_T45_)0;}

	T46 ddTakeProfit; virtual _T46_ _ddTakeProfit_(){return(_T46_)0;}

	T47 ExpMode;

	T48 ExpDays;

	T49 ExpHours;

	T50 ExpMinutes;

	T51 dExp; virtual _T51_ _dExp_(){return(_T51_)0;}

	T52 Slippage;

	T53 MyComment;

	T54 ArrowColorBuy;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDL_BuyNow()

	{

		Group = (string)"";

		Symbol = (string)CurrentSymbol();

		VolumeMode = (string)"fixed";

		VolumeSize = (double)0.1;

		VolumeSizeRisk = (double)50.0;

		VolumeRisk = (double)2.5;

		VolumePercent = (double)100.0;

		VolumeBlockPercent = (double)3.0;

		FixedRatioUnitSize = (double)0.01;

		FixedRatioDelta = (double)20.0;

		mmTradesPool = (int)0;

		mmMgInitialLots = (double)0.1;

		mmMgMultiplyOnLoss = (double)2.0;

		mmMgMultiplyOnProfit = (double)1.0;

		mmMgAddLotsOnLoss = (double)0.0;

		mmMgAddLotsOnProfit = (double)0.0;

		mmMgResetOnLoss = (int)0;

		mmMgResetOnProfit = (int)1;

		mm1326InitialLots = (double)0.1;

		mm1326Reverse = (bool)false;

		mmFiboInitialLots = (double)0.1;

		mmDalembertInitialLots = (double)0.1;

		mmDalembertReverse = (bool)false;

		mmLabouchereInitialLots = (double)0.1;

		mmLabouchereList = (string)"1,2,3,4,5,6";

		mmLabouchereReverse = (bool)false;

		mmSeqBaseLots = (double)0.1;

		mmSeqOnLoss = (string)"3,2,6";

		mmSeqOnProfit = (string)"1";

		mmSeqReverse = (bool)false;

		VolumeUpperLimit = (double)0.0;

		StopLossMode = (string)"fixed";

		StopLossPips = (double)50.0;

		StopLossPercentPrice = (double)0.55;

		StopLossPercentTP = (double)100.0;

		TakeProfitMode = (string)"fixed";

		TakeProfitPips = (double)50.0;

		TakeProfitPercentPrice = (double)0.55;

		TakeProfitPercentSL = (double)100.0;

		ExpMode = (string)"GTC";

		ExpDays = (int)0;

		ExpHours = (int)1;

		ExpMinutes = (int)0;

		Slippage = (ulong)4;

		MyComment = (string)"";

		ArrowColorBuy = (color)clrBlue;

	}



	public: /* The main method */

	virtual void _execute_()

	{

		//-- stops ------------------------------------------------------------------

		double sll = 0, slp = 0, tpl = 0, tpp = 0;

		

		     if (StopLossMode == "fixed")         {slp = StopLossPips;}

		else if (StopLossMode == "dynamicPips")   {slp = _dpStopLoss_();}

		else if (StopLossMode == "dynamicDigits") {slp = toPips(_ddStopLoss_(),Symbol);}

		else if (StopLossMode == "dynamicLevel")  {sll = _dlStopLoss_();}

		else if (StopLossMode == "percentPrice")  {sll = SymbolAsk(Symbol) - (SymbolAsk(Symbol) * StopLossPercentPrice / 100);}

		

		     if (TakeProfitMode == "fixed")         {tpp = TakeProfitPips;}

		else if (TakeProfitMode == "dynamicPips")   {tpp = _dpTakeProfit_();}

		else if (TakeProfitMode == "dynamicDigits") {tpp = toPips(_ddTakeProfit_(),Symbol);}

		else if (TakeProfitMode == "dynamicLevel")  {tpl = _dlTakeProfit_();}

		else if (TakeProfitMode == "percentPrice")  {tpl = SymbolAsk(Symbol) + (SymbolAsk(Symbol) * TakeProfitPercentPrice / 100);}

		

		if (StopLossMode == "percentTP") {

		   if (tpp > 0) {slp = tpp*StopLossPercentTP/100;}

		   if (tpl > 0) {slp = toPips(MathAbs(SymbolAsk(Symbol) - tpl), Symbol)*StopLossPercentTP/100;}

		}

		if (TakeProfitMode == "percentSL") {

		   if (slp > 0) {tpp = slp*TakeProfitPercentSL/100;}

		   if (sll > 0) {tpp = toPips(MathAbs(SymbolAsk(Symbol) - sll), Symbol)*TakeProfitPercentSL/100;}

		}

		

		//-- lots -------------------------------------------------------------------

		double lots = 0;

		double pre_sll = sll;

		

		if (pre_sll == 0) {

			pre_sll = SymbolAsk(Symbol);

		}

		

		double pre_sl_pips = toPips(SymbolAsk(Symbol)-(pre_sll-toDigits(slp,Symbol)), Symbol);

		

		     if (VolumeMode == "fixed")            {lots = DynamicLots(Symbol, VolumeMode, VolumeSize);}

		else if (VolumeMode == "block-equity")     {lots = DynamicLots(Symbol, VolumeMode, VolumeBlockPercent);}

		else if (VolumeMode == "block-balance")    {lots = DynamicLots(Symbol, VolumeMode, VolumeBlockPercent);}

		else if (VolumeMode == "block-freemargin") {lots = DynamicLots(Symbol, VolumeMode, VolumeBlockPercent);}

		else if (VolumeMode == "equity")           {lots = DynamicLots(Symbol, VolumeMode, VolumePercent);}

		else if (VolumeMode == "balance")          {lots = DynamicLots(Symbol, VolumeMode, VolumePercent);}

		else if (VolumeMode == "freemargin")       {lots = DynamicLots(Symbol, VolumeMode, VolumePercent);}

		else if (VolumeMode == "equityRisk")       {lots = DynamicLots(Symbol, VolumeMode, VolumeRisk, pre_sl_pips);}

		else if (VolumeMode == "balanceRisk")      {lots = DynamicLots(Symbol, VolumeMode, VolumeRisk, pre_sl_pips);}

		else if (VolumeMode == "freemarginRisk")   {lots = DynamicLots(Symbol, VolumeMode, VolumeRisk, pre_sl_pips);}

		else if (VolumeMode == "fixedRisk")        {lots = DynamicLots(Symbol, VolumeMode, VolumeSizeRisk, pre_sl_pips);}

		else if (VolumeMode == "fixedRatio")       {lots = DynamicLots(Symbol, VolumeMode, FixedRatioUnitSize, FixedRatioDelta);}

		else if (VolumeMode == "dynamic")          {lots = _dVolumeSize_();}

		else if (VolumeMode == "1326")             {lots = Bet1326(Group, Symbol, mmTradesPool, mm1326InitialLots, mm1326Reverse);}

		else if (VolumeMode == "fibonacci")        {lots = BetFibonacci(Group, Symbol, mmTradesPool, mmFiboInitialLots);}

		else if (VolumeMode == "dalembert")        {lots = BetDalembert(Group, Symbol, mmTradesPool, mmDalembertInitialLots, mmDalembertReverse);}

		else if (VolumeMode == "labouchere")       {lots = BetLabouchere(Group, Symbol, mmTradesPool, mmLabouchereInitialLots, mmLabouchereList, mmLabouchereReverse);}

		else if (VolumeMode == "martingale")       {lots = BetMartingale(Group, Symbol, mmTradesPool, mmMgInitialLots, mmMgMultiplyOnLoss, mmMgMultiplyOnProfit, mmMgAddLotsOnLoss, mmMgAddLotsOnProfit, mmMgResetOnLoss, mmMgResetOnProfit);}

		else if (VolumeMode == "sequence")         {lots = BetSequence(Group, Symbol, mmTradesPool, mmSeqBaseLots, mmSeqOnLoss, mmSeqOnProfit, mmSeqReverse);}

		

		lots = AlignLots(Symbol, lots, 0, VolumeUpperLimit);

		

		datetime exp = ExpirationTime(ExpMode,ExpDays,ExpHours,ExpMinutes,_dExp_());

		

		//-- send -------------------------------------------------------------------

		long ticket = BuyNow(Symbol, lots, sll, tpl, slp, tpp, Slippage, (MagicStart+(int)Group), MyComment, ArrowColorBuy, exp);

		

		if (ticket > 0) {_callback_(1);} else {_callback_(0);}

	}

};



// "Sell now" model

template<typename T1,typename T2,typename T3,typename T4,typename T5,typename T6,typename T7,typename T8,typename T9,typename _T9_,typename T10,typename T11,typename T12,typename T13,typename T14,typename T15,typename T16,typename T17,typename T18,typename T19,typename T20,typename T21,typename T22,typename T23,typename T24,typename T25,typename T26,typename T27,typename T28,typename T29,typename T30,typename T31,typename T32,typename T33,typename T34,typename T35,typename T36,typename T37,typename _T37_,typename T38,typename _T38_,typename T39,typename _T39_,typename T40,typename T41,typename T42,typename T43,typename T44,typename _T44_,typename T45,typename _T45_,typename T46,typename _T46_,typename T47,typename T48,typename T49,typename T50,typename T51,typename _T51_,typename T52,typename T53,typename T54>

class MDL_SellNow: public BlockCalls

{

	public: /* Input Parameters */

	T1 Group;

	T2 Symbol;

	T3 VolumeMode;

	T4 VolumeSize;

	T5 VolumeSizeRisk;

	T6 VolumeRisk;

	T7 VolumePercent;

	T8 VolumeBlockPercent;

	T9 dVolumeSize; virtual _T9_ _dVolumeSize_(){return(_T9_)0;}

	T10 FixedRatioUnitSize;

	T11 FixedRatioDelta;

	T12 mmTradesPool;

	T13 mmMgInitialLots;

	T14 mmMgMultiplyOnLoss;

	T15 mmMgMultiplyOnProfit;

	T16 mmMgAddLotsOnLoss;

	T17 mmMgAddLotsOnProfit;

	T18 mmMgResetOnLoss;

	T19 mmMgResetOnProfit;

	T20 mm1326InitialLots;

	T21 mm1326Reverse;

	T22 mmFiboInitialLots;

	T23 mmDalembertInitialLots;

	T24 mmDalembertReverse;

	T25 mmLabouchereInitialLots;

	T26 mmLabouchereList;

	T27 mmLabouchereReverse;

	T28 mmSeqBaseLots;

	T29 mmSeqOnLoss;

	T30 mmSeqOnProfit;

	T31 mmSeqReverse;

	T32 VolumeUpperLimit;

	T33 StopLossMode;

	T34 StopLossPips;

	T35 StopLossPercentPrice;

	T36 StopLossPercentTP;

	T37 dlStopLoss; virtual _T37_ _dlStopLoss_(){return(_T37_)0;}

	T38 dpStopLoss; virtual _T38_ _dpStopLoss_(){return(_T38_)0;}

	T39 ddStopLoss; virtual _T39_ _ddStopLoss_(){return(_T39_)0;}

	T40 TakeProfitMode;

	T41 TakeProfitPips;

	T42 TakeProfitPercentPrice;

	T43 TakeProfitPercentSL;

	T44 dlTakeProfit; virtual _T44_ _dlTakeProfit_(){return(_T44_)0;}

	T45 dpTakeProfit; virtual _T45_ _dpTakeProfit_(){return(_T45_)0;}

	T46 ddTakeProfit; virtual _T46_ _ddTakeProfit_(){return(_T46_)0;}

	T47 ExpMode;

	T48 ExpDays;

	T49 ExpHours;

	T50 ExpMinutes;

	T51 dExp; virtual _T51_ _dExp_(){return(_T51_)0;}

	T52 Slippage;

	T53 MyComment;

	T54 ArrowColorSell;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDL_SellNow()

	{

		Group = (string)"";

		Symbol = (string)CurrentSymbol();

		VolumeMode = (string)"fixed";

		VolumeSize = (double)0.1;

		VolumeSizeRisk = (double)50.0;

		VolumeRisk = (double)2.5;

		VolumePercent = (double)100.0;

		VolumeBlockPercent = (double)3.0;

		FixedRatioUnitSize = (double)0.01;

		FixedRatioDelta = (double)20.0;

		mmTradesPool = (int)0;

		mmMgInitialLots = (double)0.1;

		mmMgMultiplyOnLoss = (double)2.0;

		mmMgMultiplyOnProfit = (double)1.0;

		mmMgAddLotsOnLoss = (double)0.0;

		mmMgAddLotsOnProfit = (double)0.0;

		mmMgResetOnLoss = (int)0;

		mmMgResetOnProfit = (int)1;

		mm1326InitialLots = (double)0.1;

		mm1326Reverse = (bool)false;

		mmFiboInitialLots = (double)0.1;

		mmDalembertInitialLots = (double)0.1;

		mmDalembertReverse = (bool)false;

		mmLabouchereInitialLots = (double)0.1;

		mmLabouchereList = (string)"1,2,3,4,5,6";

		mmLabouchereReverse = (bool)false;

		mmSeqBaseLots = (double)0.1;

		mmSeqOnLoss = (string)"3,2,6";

		mmSeqOnProfit = (string)"1";

		mmSeqReverse = (bool)false;

		VolumeUpperLimit = (double)0.0;

		StopLossMode = (string)"fixed";

		StopLossPips = (double)50.0;

		StopLossPercentPrice = (double)0.55;

		StopLossPercentTP = (double)100.0;

		TakeProfitMode = (string)"fixed";

		TakeProfitPips = (double)50.0;

		TakeProfitPercentPrice = (double)0.55;

		TakeProfitPercentSL = (double)100.0;

		ExpMode = (string)"GTC";

		ExpDays = (int)0;

		ExpHours = (int)1;

		ExpMinutes = (int)0;

		Slippage = (ulong)4;

		MyComment = (string)"";

		ArrowColorSell = (color)clrRed;

	}



	public: /* The main method */

	virtual void _execute_()

	{

		//-- stops ------------------------------------------------------------------

		double sll = 0, slp = 0, tpl = 0, tpp = 0;

		

		     if (StopLossMode == "fixed")         {slp = StopLossPips;}

		else if (StopLossMode == "dynamicPips")   {slp = _dpStopLoss_();}

		else if (StopLossMode == "dynamicDigits") {slp = toPips(_ddStopLoss_(),Symbol);}

		else if (StopLossMode == "dynamicLevel")  {sll = _dlStopLoss_();}

		else if (StopLossMode == "percentPrice")  {sll = SymbolBid(Symbol) + (SymbolBid(Symbol) * StopLossPercentPrice / 100);}

		

		     if (TakeProfitMode == "fixed")         {tpp = TakeProfitPips;}

		else if (TakeProfitMode == "dynamicPips")   {tpp = _dpTakeProfit_();}

		else if (TakeProfitMode == "dynamicDigits") {tpp = toPips(_ddTakeProfit_(),Symbol);}

		else if (TakeProfitMode == "dynamicLevel")  {tpl = _dlTakeProfit_();}

		else if (TakeProfitMode == "percentPrice")  {tpl = SymbolBid(Symbol) - (SymbolBid(Symbol) * TakeProfitPercentPrice / 100);}

		

		if (StopLossMode == "percentTP") {

		   if (tpp > 0) {slp = tpp*StopLossPercentTP/100;}

		   if (tpl > 0) {slp = toPips(MathAbs(SymbolBid(Symbol) - tpl), Symbol)*StopLossPercentTP/100;}

		}

		if (TakeProfitMode == "percentSL") {

		   if (slp > 0) {tpp = slp*TakeProfitPercentSL/100;}

		   if (sll > 0) {tpp = toPips(MathAbs(SymbolBid(Symbol) - sll), Symbol)*TakeProfitPercentSL/100;}

		}

		

		//-- lots -------------------------------------------------------------------

		double lots = 0;

		double pre_sll = sll;

		

		if (pre_sll == 0) {

			pre_sll = SymbolBid(Symbol);

		}

		

		double pre_sl_pips = toPips((pre_sll+toDigits(slp,Symbol))-SymbolBid(Symbol), Symbol);

		

		     if (VolumeMode == "fixed")            {lots = DynamicLots(Symbol, VolumeMode, VolumeSize);}

		else if (VolumeMode == "block-equity")     {lots = DynamicLots(Symbol, VolumeMode, VolumeBlockPercent);}

		else if (VolumeMode == "block-balance")    {lots = DynamicLots(Symbol, VolumeMode, VolumeBlockPercent);}

		else if (VolumeMode == "block-freemargin") {lots = DynamicLots(Symbol, VolumeMode, VolumeBlockPercent);}

		else if (VolumeMode == "equity")           {lots = DynamicLots(Symbol, VolumeMode, VolumePercent);}

		else if (VolumeMode == "balance")          {lots = DynamicLots(Symbol, VolumeMode, VolumePercent);}

		else if (VolumeMode == "freemargin")       {lots = DynamicLots(Symbol, VolumeMode, VolumePercent);}

		else if (VolumeMode == "equityRisk")       {lots = DynamicLots(Symbol, VolumeMode, VolumeRisk, pre_sl_pips);}

		else if (VolumeMode == "balanceRisk")      {lots = DynamicLots(Symbol, VolumeMode, VolumeRisk, pre_sl_pips);}

		else if (VolumeMode == "freemarginRisk")   {lots = DynamicLots(Symbol, VolumeMode, VolumeRisk, pre_sl_pips);}

		else if (VolumeMode == "fixedRisk")        {lots = DynamicLots(Symbol, VolumeMode, VolumeSizeRisk, pre_sl_pips);}

		else if (VolumeMode == "fixedRatio")       {lots = DynamicLots(Symbol, VolumeMode, FixedRatioUnitSize, FixedRatioDelta);}

		else if (VolumeMode == "dynamic")          {lots = _dVolumeSize_();}

		else if (VolumeMode == "1326")             {lots = Bet1326(Group, Symbol, mmTradesPool, mm1326InitialLots, mm1326Reverse);}

		else if (VolumeMode == "fibonacci")        {lots = BetFibonacci(Group, Symbol, mmTradesPool, mmFiboInitialLots);}

		else if (VolumeMode == "dalembert")        {lots = BetDalembert(Group, Symbol, mmTradesPool, mmDalembertInitialLots, mmDalembertReverse);}

		else if (VolumeMode == "labouchere")       {lots = BetLabouchere(Group, Symbol, mmTradesPool, mmLabouchereInitialLots, mmLabouchereList, mmLabouchereReverse);}

		else if (VolumeMode == "martingale")       {lots = BetMartingale(Group, Symbol, mmTradesPool, mmMgInitialLots, mmMgMultiplyOnLoss, mmMgMultiplyOnProfit, mmMgAddLotsOnLoss, mmMgAddLotsOnProfit, mmMgResetOnLoss, mmMgResetOnProfit);}

		else if (VolumeMode == "sequence")         {lots = BetSequence(Group, Symbol, mmTradesPool, mmSeqBaseLots, mmSeqOnLoss, mmSeqOnProfit, mmSeqReverse);}

		

		lots = AlignLots(Symbol, lots, 0, VolumeUpperLimit);

		

		datetime exp = ExpirationTime(ExpMode,ExpDays,ExpHours,ExpMinutes,_dExp_());

		

		//-- send -------------------------------------------------------------------

		long ticket = SellNow(Symbol, lots, sll, tpl, slp, tpp, Slippage, (MagicStart+(int)Group), MyComment, ArrowColorSell, exp);

		

		if (ticket > 0) {_callback_(1);} else {_callback_(0);}

	}

};



// "Close positions" model

template<typename T1,typename T2,typename T3,typename T4,typename T5,typename T6,typename T7,typename T8>

class MDL_CloseOpened: public BlockCalls

{

	public: /* Input Parameters */

	T1 GroupMode;

	T2 Group;

	T3 SymbolMode;

	T4 Symbol;

	T5 BuysOrSells;

	T6 OrderMinutes;

	T7 Slippage;

	T8 ArrowColor;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDL_CloseOpened()

	{

		GroupMode = (string)"group";

		Group = (string)"";

		SymbolMode = (string)"symbol";

		Symbol = (string)CurrentSymbol();

		BuysOrSells = (string)"both";

		OrderMinutes = (int)0;

		Slippage = (ulong)4;

		ArrowColor = (color)clrDeepPink;

	}



	public: /* The main method */

	virtual void _execute_()

	{

		int closed_count = 0;

		bool finished    = false;

		

		while (finished == false)

		{

			int count = 0;

		

			for (int index = TradesTotal()-1; index >= 0; index--)

			{

				if (TradeSelectByIndex(index, GroupMode, Group, SymbolMode, Symbol, BuysOrSells))

				{

					datetime time_diff = TimeCurrent() - OrderOpenTime();

		

					if (time_diff < 0) {time_diff = 0;} // this actually happens sometimes

		

					if (time_diff >= 60 * OrderMinutes)

					{

						if (CloseTrade(OrderTicket(), Slippage, ArrowColor))

						{

							closed_count++;

						}

		

						count++;

					}

				}

			}

		

			if (count == 0) {finished = true;}

		}

		

		_callback_(1);

	}

};





//------------------------------------------------------------------------------------------------------------------------



// "Moving Average" model

class MDLIC_indicators_iMA

{

	public: /* Input Parameters */

	int MAperiod;

	int MAshift;

	ENUM_MA_METHOD MAmethod;

	ENUM_APPLIED_PRICE AppliedPrice;

	string Symbol;

	ENUM_TIMEFRAMES Period;

	int Shift;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDLIC_indicators_iMA()

	{

		MAperiod = (int)14;

		MAshift = (int)0;

		MAmethod = (ENUM_MA_METHOD)MODE_SMA;

		AppliedPrice = (ENUM_APPLIED_PRICE)PRICE_CLOSE;

		Symbol = (string)CurrentSymbol();

		Period = (ENUM_TIMEFRAMES)CurrentTimeframe();

		Shift = (int)0;

	}



	public: /* The main method */

	double _execute_()

	{

		return iMA(Symbol, Period, MAperiod, MAshift, MAmethod, AppliedPrice, Shift + FXD_MORE_SHIFT);

	}

};



// "Numeric" model

class MDLIC_value_value

{

	public: /* Input Parameters */

	double Value;

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDLIC_value_value()

	{

		Value = (double)1.0;

	}



	public: /* The main method */

	double _execute_()

	{

		return Value;

	}

};



// "Time" model

class MDLIC_value_time

{

	public: /* Input Parameters */

	int ModeTime;

	int TimeSource;

	string TimeStamp;

	int TimeCandleID;

	string TimeMarket;

	ENUM_TIMEFRAMES TimeCandleTimeframe;

	int TimeComponentYear;

	int TimeComponentMonth;

	double TimeComponentDay;

	double TimeComponentHour;

	double TimeComponentMinute;

	int TimeComponentSecond;

	datetime TimeValue;

	int ModeTimeShift;

	int TimeShiftYears;

	int TimeShiftMonths;

	int TimeShiftWeeks;

	double TimeShiftDays;

	double TimeShiftHours;

	double TimeShiftMinutes;

	int TimeShiftSeconds;

	bool TimeSkipWeekdays;

	/* Static Parameters */

	datetime retval;

	datetime retval0;

	datetime Time[];

	virtual void _callback_(int r) {return;}



	public: /* Constructor */

	MDLIC_value_time()

	{

		ModeTime = (int)0;

		TimeSource = (int)0;

		TimeStamp = (string)"00:00";

		TimeCandleID = (int)1;

		TimeMarket = (string)"";

		TimeCandleTimeframe = (ENUM_TIMEFRAMES)0;

		TimeComponentYear = (int)0;

		TimeComponentMonth = (int)0;

		TimeComponentDay = (double)0.0;

		TimeComponentHour = (double)12.0;

		TimeComponentMinute = (double)0.0;

		TimeComponentSecond = (int)0;

		TimeValue = (datetime)0;

		ModeTimeShift = (int)0;

		TimeShiftYears = (int)0;

		TimeShiftMonths = (int)0;

		TimeShiftWeeks = (int)0;

		TimeShiftDays = (double)0.0;

		TimeShiftHours = (double)0.0;

		TimeShiftMinutes = (double)0.0;

		TimeShiftSeconds = (int)0;

		TimeSkipWeekdays = (bool)false;

		/* Static Parameters (initial value) */

		retval =  0;

		retval0 =  0;

	}



	public: /* The main method */

	datetime _execute_()

	{

		// this is static for speed reasons

		

		if (TimeMarket == "") TimeMarket = Symbol();

		

		if (ModeTime == 0)

		{

			     if (TimeSource == 0) {retval = TimeCurrent();}

			else if (TimeSource == 1) {retval = TimeLocal() + (TimeCurrent() - TimeLocal());}

			else if (TimeSource == 2) {retval = TimeGMT() + (TimeCurrent() - TimeGMT());}

		}

		else if (ModeTime == 1)

		{

			retval  = StringToTime(TimeStamp);

			retval0 = retval;

		}

		else if (ModeTime==2)

		{

			retval = TimeFromComponents(TimeSource, TimeComponentYear, TimeComponentMonth, TimeComponentDay, TimeComponentHour, TimeComponentMinute, TimeComponentSecond);

		}

		else if (ModeTime == 3)

		{

			ArraySetAsSeries(Time,true);

			CopyTime(TimeMarket,TimeCandleTimeframe,TimeCandleID,1,Time);

			retval = Time[0];

		}

		else if (ModeTime == 4)

		{

			retval = TimeValue;

		}

		

		if (ModeTimeShift > 0)

		{

			int sh = 1;

		

			if (ModeTimeShift == 1) {sh = -1;}

		

			if (TimeShiftYears > 0 || TimeShiftMonths > 0)

			{

				int year = 0, month = 0, week = 0, day = 0, hour = 0, minute = 0, second = 0;

		

				if (ModeTime == 3)

				{

					year   = TimeComponentYear;

					month  = TimeComponentYear;

					day    = (int)MathFloor(TimeComponentDay);

					hour   = (int)(MathFloor(TimeComponentHour) + (24 * (TimeComponentDay - MathFloor(TimeComponentDay))));

					minute = (int)(MathFloor(TimeComponentMinute) + (60 * (TimeComponentHour - MathFloor(TimeComponentHour))));

					second = (int)(TimeComponentSecond + (60 * (TimeComponentMinute - MathFloor(TimeComponentMinute))));

				}

				else {

					year   = TimeYear(retval);

					month  = TimeMonth(retval);

					day    = TimeDay(retval);

					hour   = TimeHour(retval);

					minute = TimeMinute(retval);

					second = TimeSeconds(retval);

				}

		

				year  = year + TimeShiftYears * sh;

				month = month + TimeShiftMonths * sh;

		

				if (month < 0) {month = 12 - month;}

				else if (month > 12) {month = month - 12;}

		

				retval = StringToTime(IntegerToString(year)+"."+IntegerToString(month)+"."+IntegerToString(day)+" "+IntegerToString(hour)+":"+IntegerToString(minute)+":"+IntegerToString(second));

			}

		

			retval = retval + (sh * ((604800 * TimeShiftWeeks) + SecondsFromComponents(TimeShiftDays, TimeShiftHours, TimeShiftMinutes, TimeShiftSeconds)));

		

			if (TimeSkipWeekdays == true)

			{

				int weekday = TimeDayOfWeek(retval);

		

				if (sh > 0) { // forward

					     if (weekday == 0) {retval = retval + 86400;}

					else if (weekday == 6) {retval = retval + 172800;}

				}

				else if (sh < 0) { // back

					     if (weekday == 0) {retval = retval - 172800;}

					else if (weekday == 6) {retval = retval - 86400;}

				}

			}

		}

		

		

		return (datetime)retval;

	}

};





//------------------------------------------------------------------------------------------------------------------------



// Block 1 (No position)

class Block0: public MDL_NoOpenedOrders<string,string,string,string,string>

{



	public: /* Constructor */

	Block0() {

		__block_number = 0;

		__block_user_number = "1";

		_beforeExecuteEnabled = true;



		// Fill the list of outbound blocks

		int ___outbound_blocks[2] = {2,3};

		ArrayCopy(__outbound_blocks, ___outbound_blocks);

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

		if (value == 1) {

			_blocks_[2].run(0);

			_blocks_[3].run(0);

		}

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

	}

};



// Block 2 (If position)

class Block1: public MDL_IfOpenedOrders<string,string,string,string,string>

{



	public: /* Constructor */

	Block1() {

		__block_number = 1;

		__block_user_number = "2";

		_beforeExecuteEnabled = true;



		// Fill the list of outbound blocks

		int ___outbound_blocks[2] = {8,9};

		ArrayCopy(__outbound_blocks, ___outbound_blocks);

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

		if (value == 1) {

			_blocks_[8].run(1);

			_blocks_[9].run(1);

		}

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

	}

};



// Block 3 (EMA BUYS)

class Block2: public MDL_Condition<MDLIC_indicators_iMA,double,string,MDLIC_indicators_iMA,double,int>

{



	public: /* Constructor */

	Block2() {

		__block_number = 2;

		__block_user_number = "3";





		// Fill the list of outbound blocks

		int ___outbound_blocks[2] = {10,4};

		ArrayCopy(__outbound_blocks, ___outbound_blocks);



		// IC input parameters

		Lo.MAperiod = 10;

		Lo.Shift = 1;

		Ro.MAperiod = 50;

		Ro.Shift = 1;

	}



	public: /* Custom methods */

	virtual double _Lo_() {

		Lo.MAmethod = MODE_SMA;

		Lo.AppliedPrice = PRICE_CLOSE;

		Lo.Symbol = CurrentSymbol();

		Lo.Period = CurrentTimeframe();



		return Lo._execute_();

	}

	virtual double _Ro_() {

		Ro.MAmethod = MODE_SMA;

		Ro.AppliedPrice = PRICE_CLOSE;

		Ro.Symbol = CurrentSymbol();

		Ro.Period = CurrentTimeframe();



		return Ro._execute_();

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

		if (value == 1) {

			_blocks_[4].run(2);

			_blocks_[10].run(2);

			_blocks_[14].run(2);

			_blocks_[18].run(2);

			_blocks_[22].run(2);

			_blocks_[24].run(2);

			_blocks_[26].run(2);

			_blocks_[28].run(2);

			_blocks_[30].run(2);

			_blocks_[32].run(2);

		}

	}

};



// Block 4 (EMA SELLS)

class Block3: public MDL_Condition<MDLIC_indicators_iMA,double,string,MDLIC_indicators_iMA,double,int>

{



	public: /* Constructor */

	Block3() {

		__block_number = 3;

		__block_user_number = "4";





		// Fill the list of outbound blocks

		int ___outbound_blocks[2] = {11,5};

		ArrayCopy(__outbound_blocks, ___outbound_blocks);



		// IC input parameters

		Lo.MAperiod = 10;

		Lo.Shift = 1;

		Ro.MAperiod = 50;

		Ro.Shift = 1;

		// Block input parameters

		compare = "<";

	}



	public: /* Custom methods */

	virtual double _Lo_() {

		Lo.MAmethod = MODE_SMA;

		Lo.AppliedPrice = PRICE_CLOSE;

		Lo.Symbol = CurrentSymbol();

		Lo.Period = CurrentTimeframe();



		return Lo._execute_();

	}

	virtual double _Ro_() {

		Ro.MAmethod = MODE_SMA;

		Ro.AppliedPrice = PRICE_CLOSE;

		Ro.Symbol = CurrentSymbol();

		Ro.Period = CurrentTimeframe();



		return Ro._execute_();

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

		if (value == 1) {

			_blocks_[5].run(3);

			_blocks_[11].run(3);

			_blocks_[15].run(3);

			_blocks_[19].run(3);

			_blocks_[23].run(3);

			_blocks_[25].run(3);

			_blocks_[27].run(3);

			_blocks_[29].run(3);

			_blocks_[31].run(3);

			_blocks_[33].run(3);

		}

	}

};



// Block 11 (Buy now)

class Block4: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block4() {

		__block_number = 4;

		__block_user_number = "5";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp11_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};



// Block 12 (Sell now)

class Block5: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block5() {

		__block_number = 5;

		__block_user_number = "6";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp12_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};



// Block 11 (Buy now)

class Block14: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block14() {

		__block_number = 14;

		__block_user_number = "7";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp101_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};



// Block 12 (Sell now)

class Block15: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block15() {

		__block_number = 15;

		__block_user_number = "8";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp111_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};



// Block 11 (Buy now)

class Block18: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block18() {

		__block_number = 18;

		__block_user_number = "9";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp102_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};



// Block 12 (Sell now)

class Block19: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block19() {

		__block_number = 19;

		__block_user_number = "10";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp112_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};





// Block 11 (Buy now)

class Block22: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block22() {

		__block_number = 22;

		__block_user_number = "11";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp103_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};





// Block 11 (Buy now)

class Block24: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block24() {

		__block_number = 24;

		__block_user_number = "12";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp104_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};







// Block 11 (Buy now)

class Block26: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block26() {

		__block_number = 26;

		__block_user_number = "13";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp105_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};







// Block 11 (Buy now)

class Block28: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block28() {

		__block_number = 28;

		__block_user_number = "14";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp106_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};









// Block 11 (Buy now)

class Block30: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block30() {

		__block_number = 30;

		__block_user_number = "15";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp107_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};







// Block 11 (Buy now)

class Block32: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block32() {

		__block_number = 32;

		__block_user_number = "16";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp108_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};





// Block 12 (Sell now)

class Block23: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block23() {

		__block_number = 23;

		__block_user_number = "17";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp113_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};





// Block 12 (Sell now)

class Block25: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block25() {

		__block_number = 25;

		__block_user_number = "18";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp114_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};









// Block 12 (Sell now)

class Block27: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block27() {

		__block_number = 27;

		__block_user_number = "19";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp115_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};







// Block 12 (Sell now)

class Block29: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block29() {

		__block_number = 29;

		__block_user_number = "20";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp116_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};









// Block 12 (Sell now)

class Block31: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block31() {

		__block_number = 31;

		__block_user_number = "21";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp117_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};









// Block 12 (Sell now)

class Block33: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block33() {

		__block_number = 33;

		__block_user_number = "22";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp118_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};





//HAPA



// Block 13 (CLOSE BUY)

class Block6: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block6() {

		__block_number = 6;

		__block_user_number = "23";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block7: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block7() {

		__block_number = 7;

		__block_user_number = "24";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};







// Block 13 (CLOSE BUY)

class Block12: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block12() {

		__block_number = 12;

		__block_user_number = "25";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block13: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block13() {

		__block_number = 13;

		__block_user_number = "26";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};





// Block 13 (CLOSE BUY)

class Block16: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block16() {

		__block_number = 16;

		__block_user_number = "27";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block17: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block17() {

		__block_number = 17;

		__block_user_number = "28";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};





// Block 13 (CLOSE BUY)

class Block20: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block20() {

		__block_number = 20;

		__block_user_number = "29";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block21: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block21() {

		__block_number = 21;

		__block_user_number = "30";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};







// Block 13 (CLOSE BUY)

class Block34: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block34() {

		__block_number = 34;

		__block_user_number = "31";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block35: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block35() {

		__block_number = 35;

		__block_user_number = "32";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};







// Block 13 (CLOSE BUY)

class Block36: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block36() {

		__block_number = 36;

		__block_user_number = "33";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block37: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block37() {

		__block_number = 37;

		__block_user_number = "34";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};







// Block 13 (CLOSE BUY)

class Block38: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block38() {

		__block_number = 38;

		__block_user_number = "35";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block39: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block39() {

		__block_number = 39;

		__block_user_number = "36";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};









// Block 13 (CLOSE BUY)

class Block40: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block40() {

		__block_number = 40;

		__block_user_number = "37";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block41: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block41() {

		__block_number = 41;

		__block_user_number = "38";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};







// Block 13 (CLOSE BUY)

class Block42: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block42() {

		__block_number = 42;

		__block_user_number = "39";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block43: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block43() {

		__block_number = 43;

		__block_user_number = "40";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};







// Block 13 (CLOSE BUY)

class Block44: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block44() {

		__block_number = 44;

		__block_user_number = "41";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "buys";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



// Block 14 (CLOSE SELL)

class Block45: public MDL_CloseOpened<string,string,string,string,string,int,ulong,color>

{



	public: /* Constructor */

	Block45() {

		__block_number = 45;

		__block_user_number = "42";

		_beforeExecuteEnabled = true;

		// Block input parameters

		BuysOrSells = "sells";

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		ArrowColor = (color)clrDeepPink;

	}

};



//HAPA



// Block 15 (EMA BUYS)

class Block8: public MDL_Condition<MDLIC_indicators_iMA,double,string,MDLIC_indicators_iMA,double,int>

{



	public: /* Constructor */

	Block8() {

		__block_number = 8;

		__block_user_number = "43";





		// Fill the list of outbound blocks

		int ___outbound_blocks[1] = {6};

		ArrayCopy(__outbound_blocks, ___outbound_blocks);



		// IC input parameters

		Lo.MAperiod = 10;

		Lo.Shift = 1;

		Ro.MAperiod = 50;

		Ro.Shift = 1;

		// Block input parameters

		compare = "<";

	}



	public: /* Custom methods */

	virtual double _Lo_() {

		Lo.MAmethod = MODE_SMA;

		Lo.AppliedPrice = PRICE_CLOSE;

		Lo.Symbol = CurrentSymbol();

		Lo.Period = CurrentTimeframe();



		return Lo._execute_();

	}

	virtual double _Ro_() {

		Ro.MAmethod = MODE_SMA;

		Ro.AppliedPrice = PRICE_CLOSE;

		Ro.Symbol = CurrentSymbol();

		Ro.Period = CurrentTimeframe();



		return Ro._execute_();

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

		if (value == 1) {

			_blocks_[6].run(8);

		}

	}

};



// Block 16 (EMA SELLS)

class Block9: public MDL_Condition<MDLIC_indicators_iMA,double,string,MDLIC_indicators_iMA,double,int>

{



	public: /* Constructor */

	Block9() {

		__block_number = 9;

		__block_user_number = "44";





		// Fill the list of outbound blocks

		int ___outbound_blocks[1] = {7};

		ArrayCopy(__outbound_blocks, ___outbound_blocks);



		// IC input parameters

		Lo.MAperiod = 10;

		Lo.Shift = 1;

		Ro.MAperiod = 50;

		Ro.Shift = 1;

	}



	public: /* Custom methods */

	virtual double _Lo_() {

		Lo.MAmethod = MODE_SMA;

		Lo.AppliedPrice = PRICE_CLOSE;

		Lo.Symbol = CurrentSymbol();

		Lo.Period = CurrentTimeframe();



		return Lo._execute_();

	}

	virtual double _Ro_() {

		Ro.MAmethod = MODE_SMA;

		Ro.AppliedPrice = PRICE_CLOSE;

		Ro.Symbol = CurrentSymbol();

		Ro.Period = CurrentTimeframe();



		return Ro._execute_();

	}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

		if (value == 1) {

			_blocks_[7].run(9);

		}

	}

};



// Block 17 (Buy now)

class Block10: public MDL_BuyNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block10() {

		__block_number = 10;

		__block_user_number = "45";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp17_VolumeSize;

		ArrowColorBuy = (color)clrBlue;

	}

};



// Block 18 (Sell now)

class Block11: public MDL_SellNow<string,string,string,double,double,double,double,double,MDLIC_value_value,double,double,double,int,double,double,double,double,double,int,int,double,bool,double,double,bool,double,string,bool,double,string,string,bool,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,double,double,double,MDLIC_value_value,double,MDLIC_value_value,double,MDLIC_value_value,double,string,int,int,int,MDLIC_value_time,datetime,ulong,string,color>

{



	public: /* Constructor */

	Block11() {

		__block_number = 11;

		__block_user_number = "46";

		_beforeExecuteEnabled = true;



		// IC input parameters

		dVolumeSize.Value = 0.1;

		dpStopLoss.Value = 100.0;

		ddStopLoss.Value = 0.01;

		dpTakeProfit.Value = 100.0;

		ddTakeProfit.Value = 0.01;

		dExp.ModeTimeShift = 2;

		dExp.TimeShiftDays = 1.0;

		dExp.TimeSkipWeekdays = true;

		// Block input parameters

		StopLossMode = "none";

		TakeProfitMode = "none";

		ExpMode = "specified";

		ExpDays = 7;

		ExpHours = 0;

		MyComment = "MM3.0 FLIP CODEPRO";

	}



	public: /* Custom methods */

	virtual double _dVolumeSize_() {return dVolumeSize._execute_();}

	virtual double _dlStopLoss_() {return dlStopLoss._execute_();}

	virtual double _dpStopLoss_() {return dpStopLoss._execute_();}

	virtual double _ddStopLoss_() {return ddStopLoss._execute_();}

	virtual double _dlTakeProfit_() {return dlTakeProfit._execute_();}

	virtual double _dpTakeProfit_() {return dpTakeProfit._execute_();}

	virtual double _ddTakeProfit_() {return ddTakeProfit._execute_();}

	virtual datetime _dExp_() {return dExp._execute_();}



	public: /* Callback & Run */

	virtual void _callback_(int value) {

	}



	virtual void _beforeExecute_()

	{



		Symbol = (string)CurrentSymbol();

		VolumeSize = (double)_externs::inp18_VolumeSize;

		ArrowColorSell = (color)clrRed;

	}

};





/************************************************************************************************************************/

// +------------------------------------------------------------------------------------------------------------------+ //

// |                                                   Functions                                                      | //

// |                                 System and Custom functions used in the program                                  | //

// +------------------------------------------------------------------------------------------------------------------+ //

/************************************************************************************************************************/





double AccountBalance()

{

	return NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);

}



double AccountBalanceAtStart()

{

	// This function MUST be run once at pogram's start

	static double memory = 0;



	if (memory == 0)

	{

		memory = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);

	}



	return memory;

}



double AccountEquity()

{

	return AccountInfoDouble(ACCOUNT_EQUITY);

}



double AccountFreeMargin()

{

	return AccountInfoDouble(ACCOUNT_FREEMARGIN);

}



double AlignLots(string symbol, double lots, double lowerlots = 0.0, double upperlots = 0.0)

{

	double LotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

	double LotSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

	double MinLots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

	double MaxLots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);



	if (LotStep > MinLots) MinLots = LotStep;



	if (lots == EMPTY_VALUE) {lots = 0.0;}



	lots = MathRound(lots / LotStep) * LotStep;



	if (lots < MinLots) {lots = MinLots;}

	if (lots > MaxLots) {lots = MaxLots;}



	if (lowerlots > 0.0)

	{

		lowerlots = MathRound(lowerlots / LotStep) * LotStep;

		if (lots < lowerlots) {lots = lowerlots;}

	}



	if (upperlots > 0.0)

	{

		upperlots = MathRound(upperlots / LotStep) * LotStep;

		if (lots > upperlots) {lots = upperlots;}

	}



	return lots;

}



double AlignStopLoss(

	string symbol,

	int type,

	double price,

	double slo = 0.0, // original sl, used when modifying

	double sll = 0.0,

	double slp = 0.0,

	bool consider_freezelevel = false

	)

{

	double sl = 0.0;

	

	if (MathAbs(sll) == EMPTY_VALUE) {sll = 0.0;}

	if (MathAbs(slp) == EMPTY_VALUE) {slp = 0.0;}



	if (sll == 0.0 && slp == 0.0)

	{

		return 0.0;

	}



	if (price <= 0.0)

	{

		Print(__FUNCTION__ + " error: No price entered");



		return -1;

	}



	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

	int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

	slp          = slp * PipValue(symbol) * point;



	//-- buy-sell identifier ---------------------------------------------

	int bs = 1;



	if (

		   type == ORDER_TYPE_SELL

		|| type == ORDER_TYPE_SELL_STOP

		|| type == ORDER_TYPE_SELL_LIMIT

		|| type == ORDER_TYPE_SELL_STOP_LIMIT

		)

	{

		bs = -1;

	}



	//-- prices that will be used ----------------------------------------

	double askbid = price;

	double bidask = price;



	if (type < 2)

	{

		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);



		askbid = ask;

		bidask = bid;



		if (bs < 0)

		{

		  askbid = bid;

		  bidask = ask;

		}

	}



	//-- build sl level -------------------------------------------------- 

	if (sll == 0.0 && slp != 0.0) {sll = price;}



	if (sll > 0.0) {sl = sll - slp * bs;}



	if (sl < 0.0)

	{

		return -1;

	}



	sl  = NormalizeDouble(sl, digits);

	slo = NormalizeDouble(slo, digits);



	if (sl == slo)

	{

		return sl;

	}



	//-- build limit levels ----------------------------------------------

	double minstops = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);



	if (consider_freezelevel == true)

	{

		double freezelevel = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);



		if (freezelevel > minstops) {minstops = freezelevel;}

	}



	minstops = NormalizeDouble(minstops * point,digits);



	double sllimit = bidask - minstops * bs; // SL min price level



	//-- check and align sl, print errors --------------------------------

	//-- do not do it when the stop is the same as the original

	if (sl > 0.0 && sl != slo)

	{

		if ((bs > 0 && sl > askbid) || (bs < 0 && sl < askbid))

		{

			string abstr = "";



			if (bs > 0) {abstr = "Bid";} else {abstr = "Ask";}



			Print(

				"Error: Invalid SL requested (",

				DoubleToStr(sl, digits),

				" for ", abstr, " price ",

				bidask,

				")"

			);



			return -1;

		}

		else if ((bs > 0 && sl > sllimit) || (bs < 0 && sl < sllimit))

		{

			if (USE_VIRTUAL_STOPS)

			{

				return sl;

			}



			Print(

				"Warning: Too short SL requested (",

				DoubleToStr(sl, digits),

				" or ",

				DoubleToStr(MathAbs(sl - askbid) / point, 0),

				" points), minimum will be taken (",

				DoubleToStr(sllimit, digits),

				" or ",

				DoubleToStr(MathAbs(askbid - sllimit) / point, 0),

				" points)"

			);



			sl = sllimit;



			return sl;

		}

	}



	// align by the ticksize

	double ticksize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

	sl = MathRound(sl / ticksize) * ticksize;



	return sl;

}



double AlignTakeProfit(

	string symbol,

	int type,

	double price,

	double tpo = 0.0, // original tp, used when modifying

	double tpl = 0.0,

	double tpp = 0.0,

	bool consider_freezelevel = false

	)

{

	double tp = 0.0;

	

	if (MathAbs(tpl) == EMPTY_VALUE) {tpl = 0.0;}

	if (MathAbs(tpp) == EMPTY_VALUE) {tpp = 0.0;}



	if (tpl == 0.0 && tpp == 0.0)

	{

		return 0.0;

	}



	if (price <= 0.0)

	{

		Print(__FUNCTION__ + " error: No price entered");



		return -1;

	}



	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

	int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

	tpp          = tpp * PipValue(symbol) * point;

	

	//-- buy-sell identifier ---------------------------------------------

	int bs = 1;



	if (

		   type == ORDER_TYPE_SELL

		|| type == ORDER_TYPE_SELL_STOP

		|| type == ORDER_TYPE_SELL_LIMIT

		|| type == ORDER_TYPE_SELL_STOP_LIMIT

		)

	{

		bs = -1;

	}

	

	//-- prices that will be used ----------------------------------------

	double askbid = price;

	double bidask = price;

	

	if (type < 2)

	{

		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

		

		askbid = ask;

		bidask = bid;



		if (bs < 0)

		{

		  askbid = bid;

		  bidask = ask;

		}

	}

	

	//-- build tp level --------------------------------------------------- 

	if (tpl == 0.0 && tpp != 0.0) {tpl = price;}



	if (tpl > 0.0) {tp = tpl + tpp * bs;}

	

	if (tp < 0.0)

	{

		return -1;

	}



	tp  = NormalizeDouble(tp, digits);

	tpo = NormalizeDouble(tpo, digits);



	if (tp == tpo)

	{

		return tp;

	}

	

	//-- build limit levels ----------------------------------------------

	double minstops = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);



	if (consider_freezelevel == true)

	{

		double freezelevel = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);



		if (freezelevel > minstops) {minstops = freezelevel;}

	}



	minstops = NormalizeDouble(minstops * point,digits);

	

	double tplimit = bidask + minstops * bs; // TP min price level

	

	//-- check and align tp, print errors --------------------------------

	//-- do not do it when the stop is the same as the original

	if (tp > 0.0 && tp != tpo)

	{

		if ((bs > 0 && tp < bidask) || (bs < 0 && tp > bidask))

		{

			string abstr = "";



			if (bs > 0) {abstr = "Bid";} else {abstr = "Ask";}



			Print(

				"Error: Invalid TP requested (",

				DoubleToStr(tp, digits),

				" for ", abstr, " price ",

				bidask,

				")"

			);



			return -1;

		}

		else if ((bs > 0 && tp < tplimit) || (bs < 0 && tp > tplimit))

		{

			if (USE_VIRTUAL_STOPS)

			{

				return tp;

			}



			Print(

				"Warning: Too short TP requested (",

				DoubleToStr(tp, digits),

				" or ",

				DoubleToStr(MathAbs(tp - askbid) / point, 0),

				" points), minimum will be taken (",

				DoubleToStr(tplimit, digits),

				" or ",

				DoubleToStr(MathAbs(askbid - tplimit) / point, 0),

				" points)"

			);



			tp = tplimit;



			return tp;

		}

	}

	

	// align by the ticksize

	double ticksize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

	tp = MathRound(tp / ticksize) * ticksize;

	

	return tp;

}



template<typename T>

bool ArrayEnsureValue(T &array[], T value)

{

	int size   = ArraySize(array);



	if (size > 0)

	{

		if (InArray(array, value))

		{

			// value found -> exit

			return false; // no value added

		}

	}



	// value does not exists -> add it

	ArrayResize(array, size+1);

	array[size] = value;



	return true; // value added

}



template<typename T>

int ArraySearch(T &array[], T value)

{

	int index = -1;

	int size  = ArraySize(array);



	for (int i = 0; i < size; i++)

	{

		if (array[i] == value)

		{

			index = i;

			break;

		}  

	}



   return index;

}



template<typename T>

bool ArrayStripKey(T &array[], int key)

{

	int x    = 0;

	int size = ArraySize(array);



	for (int i=0; i<size; i++)

	{

		if (i != key)

		{

			array[x] = array[i];

			x++;

		}

	}



	if (x < size)

	{

		ArrayResize(array, x);

		

		return true; // stripped

	}



	return false; // not stripped

}



template<typename T>

bool ArrayStripValue(T &array[], T value)

{

	int x    = 0;

	int size = ArraySize(array);



	for (int i=0; i<size; i++)

	{

		if (array[i] != value)

		{

			array[x] = array[i];

			x++;

		}

	}



	if (x < size)

	{

		ArrayResize(array, x);

		

		return true; // stripped

	}



	return false; // not stripped

}



double Bet1326(

	string group,

	string symbol,

	int pool,

	double initialLots,

	bool reverse = false

) {  

	double info[];

	GetBetTradesInfo(info, group, symbol, pool, false);



	double lots         = info[0];

	double profitOrLoss = info[1]; // 0 - unknown, 1 - profit, -1 - loss



	//-- 1-3-2-6 Logic

	double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);



	if (initialLots < minLot)

	{

		initialLots = minLot;  

	}



	if (lots == 0)

	{

		lots = initialLots;

	}

	else

	{

		if (

			   (reverse == false && profitOrLoss == 1)

			|| (reverse == true && profitOrLoss == -1)

		) {

			double div = lots / initialLots;



			     if (div < 1.5) {lots = initialLots * 3;}

			else if (div < 2.5) {lots = initialLots * 6;}

			else if (div < 3.5) {lots = initialLots * 2;}

			else {lots = initialLots;}

		}

		else

		{

			lots = initialLots;

		}

	}



	return lots;

}



double BetDalembert(

	string group,

	string symbol,

	int pool,

	double initialLots,

	double reverse = false

) {  

	double info[];

	GetBetTradesInfo(info, group, symbol, pool, false);



	double lots         = info[0];

	double profitOrLoss = info[1]; // 0 - unknown, 1 - profit, -1 - loss



	//-- Dalembert Logic

	double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);



	if (initialLots < minLot)

	{

		initialLots = minLot;  

	}



	if (lots == 0)

	{

		lots = initialLots;

	}

	else

	{

		if (

			   (reverse == 0 && profitOrLoss == 1)

			|| (reverse == 1 && profitOrLoss == -1)

		) {

			lots = lots - initialLots;

			if (lots < initialLots) {lots = initialLots;}

		}

		else

		{

			lots = lots + initialLots;

		}

	}



	return lots;

}



double BetFibonacci(

	string group,

	string symbol,

	int pool,

	double initialLots

) {

	double info[];

	GetBetTradesInfo(info, group, symbol, pool, false);



	double lots         = info[0];

	double profitOrLoss = info[1]; // 0 - unknown, 1 - profit, -1 - loss



	//-- Fibonacci Logic

	double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);



	if (initialLots < minLot)

	{

		initialLots = minLot;  

	}



	if (lots == 0)

	{

		lots = initialLots;

	}

	else

	{  

		int fibo1 = 1;

		int fibo2 = 0;

		int fibo3 = 0;

		int fibo4 = 0;

		double div = lots / initialLots;



		if (div <= 0) {div = 1;}



		while (true)

		{

			fibo1 = fibo1 + fibo2;

			fibo3 = fibo2;

			fibo2 = fibo1 - fibo2;

			fibo4 = fibo2 - fibo3;



			if (fibo1 > NormalizeDouble(div, 2))

			{

				break;

			}

		}



		if (profitOrLoss == 1)

		{

			if (fibo4 <= 0) {fibo4 = 1;}

			lots = initialLots * fibo4;

		}

		else

		{

			lots = initialLots * fibo1;

		}

	}



	lots = NormalizeDouble(lots, 2);



	return lots;

}



double BetLabouchere(

	string group,

	string symbol,

	int pool,

	double initialLots,

	string listOfNumbers,

	double reverse = false

) {

	double info[];

	GetBetTradesInfo(info, group, symbol, pool, false);



	double lots         = info[0];

	double profitOrLoss = info[1]; // 0 - unknown, 1 - profit, -1 - loss



	//-- Labouchere Logic

	static string memGroup[];

	static string memList[];

	static long memTicket[];



	int startAgain = false;



	//- get the list of numbers as it is stored in the memory, or store it

	int id = ArraySearch(memGroup, group);



	if (id == -1)

	{

		startAgain = true;



		if (listOfNumbers == "") {listOfNumbers = "1";}



		id = ArraySize(memGroup);



		ArrayResize(memGroup, id+1, id+1);

		ArrayResize(memList, id+1, id+1);

		ArrayResize(memTicket, id+1, id+1);



		memGroup[id] = group;

		memList[id]  = listOfNumbers;

	}



	if (memTicket[id] == (long)OrderTicket())

	{

		// the last known ticket (memTicket[id]) should be different than OderTicket() normally

		// when failed to create a new trade - the last ticket remains the same

		// so we need to reset

		memList[id] = listOfNumbers;

	}



	memTicket[id] = (long)OrderTicket();



	//- now turn the string into integer array

	int list[];

	string listS[];



	StringExplode(",", memList[id], listS);

	ArrayResize(list, ArraySize(listS));



	for (int s = 0; s < ArraySize(listS); s++)

	{

		list[s] = (int)StringToInteger(StringTrim(listS[s]));  

	}



	//-- 

	int size = ArraySize(list);



	double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);



	if (initialLots < minLot)

	{

		initialLots = minLot;  

	}



	if (lots == 0)

	{

		startAgain = true;

	}



	if (startAgain == true)

	{

		if (size == 1)

		{

			lots = initialLots * list[0];

		}

		else {

			lots = initialLots * (list[0] + list[size-1]);

		}

	}

	else 

	{

		if (

			   (reverse == 0 && profitOrLoss == 1)

			|| (reverse == 1 && profitOrLoss == -1)

		) {

			size = size - 2;

			

			if (size < 0) {

				size = 0;

			}

			

			if (size == 0) {

				// Set the initial list of numbers

				StringExplode(",", listOfNumbers, listS);

				ArrayResize(list, ArraySize(listS));

			

				for (int s = 0; s < ArraySize(listS); s++)

				{

					list[s] = (int)StringToInteger(StringTrim(listS[s]));  

				}

				

				size = ArraySize(list);

			}

			else {

				// Cancel the first and the last number in the list

				// shift array 1 step left

				for (int pos = 0; pos < ArraySize(list) - 1; pos++) {

					list[pos] = list[pos+1];

				}

				

				ArrayResize(list, size);

			}

			

			int rightNum = (size > 1) ? list[size - 1] : 0;

			lots = initialLots * (list[0] + rightNum);



			if (lots < initialLots) {lots = initialLots;}

		}

		else

		{

			size = size + 1;

			ArrayResize(list, size);

			

			int rightNum = (size > 2) ? list[size - 2] : 0;



			list[size - 1] = list[0] + rightNum;

			lots       = initialLots * (list[0] + list[size - 1]);



			if (lots < initialLots) {lots = initialLots;}

		}

	}



	Print("Labouchere (for group "

		+ (string)id

		+ ") current list of numbers: "

		+ StringImplode(",", list)

	);



	size=ArraySize(list);



	if (size == 0)

	{

		ArrayStripKey(memGroup, id);

		ArrayStripKey(memList, id);

		ArrayStripKey(memTicket, id);

	}

	else {

		memList[id] = StringImplode(",", list);

	}



	return lots;

}



double BetMartingale(

	string group,

	string symbol,

	int pool,

	double initialLots,

	double multiplyOnLoss,

	double multiplyOnProfit,

	double addOnLoss,

	double addOnProfit,

	int resetOnLoss,

	int resetOnProfit

) {

	double info[];

	GetBetTradesInfo(info, group, symbol, pool, true);



	double lots         = info[0];

	double profitOrLoss = info[1]; // 0 - unknown, 1 - profit, -1 - loss

	double consecutive  = info[2];



	//-- Martingale Logic

	if (lots == 0)

	{

		lots = initialLots;

	}

	else

	{

		if (profitOrLoss == 1)

		{

			if (resetOnProfit > 0 && consecutive >= resetOnProfit)

			{

				lots = initialLots;

			}

			else

			{

				if (multiplyOnProfit <= 0)

				{

					multiplyOnProfit = 1;

				}



				lots = (lots * multiplyOnProfit) + addOnProfit;

			}

		}

		else

		{

			if (resetOnLoss > 0 && consecutive >= resetOnLoss)

			{

				lots = initialLots;  

			}

			else

			{

				if (multiplyOnLoss <= 0)

				{

					multiplyOnLoss = 1;

				}



				lots = (lots * multiplyOnLoss) + addOnLoss;

			}

		}

	}



	return lots;

}



double BetSequence(

	string group,

	string symbol,

	int pool,

	double initialLots,

	string sequenceOnLoss,

	string sequenceOnProfit,

	bool reverse = false

) {  

	double info[];

	GetBetTradesInfo(info, group, symbol, pool, false);



	double lots         = info[0];

	double profitOrLoss = info[1]; // 0 - unknown, 1 - profit, -1 - loss



	//-- Sequence stuff

	static string memGroup[];

	static string memLossList[];

	static string memProfitList[];

	static long memTicket[];



	//- get the list of numbers as it is stored in the memory, or store it

	int id = ArraySearch(memGroup, group);



	if (id == -1)

	{

		if (sequenceOnLoss == "") {sequenceOnLoss = "1";}



		if (sequenceOnProfit == "") {sequenceOnProfit = "1";}



		id = ArraySize(memGroup);



		ArrayResize(memGroup, id+1, id+1);

		ArrayResize(memLossList, id+1, id+1);

		ArrayResize(memProfitList, id+1, id+1);

		ArrayResize(memTicket, id+1, id+1);



		memGroup[id]      = group;

		memLossList[id]   = sequenceOnLoss;

		memProfitList[id] = sequenceOnProfit;

	}



	bool lossReset   = false;

	bool profitReset = false;



	if (profitOrLoss == -1 && memLossList[id] == "")

	{

		lossReset         = true;

		memProfitList[id] = "";

	}



	if (profitOrLoss == 1 && memProfitList[id] == "")

	{

		profitReset     = true;

		memLossList[id] = "";

	}



	if (profitOrLoss == 1 || memLossList[id] == "")

	{

		memLossList[id] = sequenceOnLoss;



		if (lossReset) {

			memLossList[id] = "1," + memLossList[id];

		}

	}



	if (profitOrLoss == -1 || memProfitList[id] == "")

	{

		memProfitList[id] = sequenceOnProfit;



		if (profitReset) {

			memProfitList[id] = "1," + memProfitList[id];

		}

	}



	if (memTicket[id] == (long)OrderTicket())

	{

		// Normally the last known ticket (memTicket[id]) should be different than OderTicket()

		// when failed to create a new trade, the last ticket remains the same

		// so we need to reset

		memLossList[id]   = sequenceOnLoss;

		memProfitList[id] = sequenceOnProfit;

	}



	memTicket[id] = (long)OrderTicket();



	//- now turn the string into integer array

	int s = 0;

	double listLoss[];

	double listProfit[];

	string listS[];



	StringExplode(",", memLossList[id], listS);

	ArrayResize(listLoss, ArraySize(listS), ArraySize(listS));



	for (s = 0; s < ArraySize(listS); s++)

	{

		listLoss[s] = (double)StringToDouble(StringTrim(listS[s]));  

	}



	StringExplode(",", memProfitList[id], listS);

	ArrayResize(listProfit, ArraySize(listS), ArraySize(listS));



	for (s = 0; s < ArraySize(listS); s++)

	{

		listProfit[s] = (double)StringToDouble(StringTrim(listS[s]));  

	}



	//--

	double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);



	if (initialLots < minLot)

	{

		initialLots = minLot;  

	}



	if (lots == 0)

	{

		lots = initialLots;

	}

	else

	{

		if (

			   (reverse == false && profitOrLoss ==1)

			|| (reverse == true && profitOrLoss == -1)

		) {

			lots = initialLots * listProfit[0];



			// shift array 1 step left

			int size = ArraySize(listProfit);



			for(int pos = 0; pos < size-1; pos++)

			{

				listProfit[pos] = listProfit[pos+1];

			}



			if (size > 0)

			{

				ArrayResize(listProfit, size-1, size-1);

				memProfitList[id] = StringImplode(",", listProfit);

			}

		}

		else

		{

			lots = initialLots * listLoss[0];



			// shift array 1 step left

			int size = ArraySize(listLoss);



			for(int pos = 0; pos < size-1; pos++)

			{

				listLoss[pos] = listLoss[pos+1];

			}



			if (size > 0)

			{

				ArrayResize(listLoss, size-1, size-1);

				memLossList[id] = StringImplode(",", listLoss);

			}

		}

	}



	return lots;

}



long BuyNow(

	string symbol,

	double lots,

	double sll,

	double tpl,

	double slp,

	double tpp,

	double slippage = 0,

	int magic = 0,

	string comment = "",

	color arrowcolor = clrNONE,

	datetime expiration = 0

	)

{

	return OrderCreate(

		symbol,

		POSITION_TYPE_BUY,

		lots,

		0,

		sll,

		tpl,

		slp,

		tpp,

		slippage,

		magic,

		comment,

		arrowcolor,

		expiration

	);

}



int CheckForTradingError(int error_code=-1, string msg_prefix="")

{

   // return 0 -> no error

   // return 1 -> overcomable error

   // return 2 -> fatal error

   

   int retval=0;

   static int tryouts=0;

   

   //-- error check -----------------------------------------------------

   switch(error_code)

   {

      //-- no error

      case 0:

         retval=0;

         break;

      //-- overcomable errors

      case TRADE_RETCODE_REQUOTE:

      case TRADE_RETCODE_REJECT:

      case TRADE_RETCODE_ERROR:

      case TRADE_RETCODE_TIMEOUT:

      case TRADE_RETCODE_INVALID_VOLUME:

      case TRADE_RETCODE_INVALID_PRICE:

      case TRADE_RETCODE_INVALID_STOPS:

      case TRADE_RETCODE_INVALID_EXPIRATION:

      case TRADE_RETCODE_PRICE_CHANGED:

      case TRADE_RETCODE_PRICE_OFF:

      case TRADE_RETCODE_TOO_MANY_REQUESTS:

      case TRADE_RETCODE_NO_CHANGES:

      case TRADE_RETCODE_CONNECTION:

         retval=1;

         break;

      //-- critical errors

      default:

         retval=2;

         break;

   }

   

   if (error_code > 0)

   {

      string msg = "";

      if (retval == 1)

      {

         StringConcatenate(msg, msg_prefix,": ",ErrorMessage(error_code),". Retrying in 5 seconds..");

         Sleep(500); 

      }

      else if (retval == 2)

      {

         StringConcatenate(msg, msg_prefix,": ",ErrorMessage(error_code));

      }

      Print(msg);

   }

   

   if (retval==0)

   {

      tryouts=0;

   }

   else if (retval==1)

   {

      tryouts++;

      if (tryouts>=10)

      {

         tryouts=0;

         retval=2;

      }

      else

      {

         Print("retry #"+(string)tryouts+" of 10");

      }

   }

   

   return(retval);

}



bool CloseTrade(ulong ticket, ulong deviation = 0, color clr = clrNONE)

{

	while(true)

	{

		bool success = false;



		if (!PositionSelectByTicket(ticket))

		{

			return false;

		}



		string symbol = PositionGetString(POSITION_SYMBOL);

		long magic    = PositionGetInteger(POSITION_MAGIC);

		double volume = PositionGetDouble(POSITION_VOLUME);



		// With some CFD we can open position with the max volume more than once,

		// so we get a position that has volume bigger than the maximum.

		// Then we cannot close that position, because the volume is too high.

		// For that reason here we will close it in parts.

		double max_volume  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

		double part_volume = (volume > max_volume) ? max_volume : volume;



		//-- close --------------------------------------------------------

		MqlTradeRequest request;

		MqlTradeResult result;

		MqlTradeCheckResult check_result;

		ZeroMemory(request);

		ZeroMemory(result);

		ZeroMemory(check_result);



		if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)

		{

			//--- prepare request for close BUY position

			request.type  = ORDER_TYPE_SELL;

			request.price = SymbolInfoDouble(symbol, SYMBOL_BID);

		}

		else

		{

			//--- prepare request for close SELL position

			request.type  = ORDER_TYPE_BUY;

			request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);

		}



		request.action    = TRADE_ACTION_DEAL;

		request.symbol    = symbol;

		request.volume    = part_volume;

		request.magic     = magic;

		request.deviation = (int)(deviation * PipValue(symbol));



		// for hedging mode

		request.position  = ticket;



		// filling type

		if (IsFillingTypeAllowed(symbol, SYMBOL_FILLING_FOK))

			request.type_filling = ORDER_FILLING_FOK;

		else if (IsFillingTypeAllowed(symbol, SYMBOL_FILLING_IOC))

			request.type_filling = ORDER_FILLING_IOC;

		else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_RETURN)) // just in case

			request.type_filling = ORDER_FILLING_RETURN;

		else

			request.type_filling = ORDER_FILLING_RETURN;



		success = OrderSend(request, result);



		//-- error check --------------------------------------------------

		if (!success || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED && result.retcode != TRADE_RETCODE_DONE_PARTIAL))

		{

			string errmsgpfx = "Closing position/trade error";



			int erraction = CheckForTradingError(result.retcode, errmsgpfx);



			switch(erraction)

			{

				case 0: break;    // no error

				case 1: continue; // overcomable error

				case 2: break;    // fatal error

			}



			return false;

		}

		

		//-- finish work --------------------------------------------------

		if (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)

		{

			// we are closing the position in parts?

			if (volume != part_volume)

			{

				continue; // continue the "while" loop, so that the whole volume could be closed

			}



			while (true)

			{

			  	if (MQLInfoInteger(MQL_TESTER) || !PositionSelectByTicket(ticket))

				{

					break;

				}



				Sleep(10);

			}

		}



		if (success == true)

		{

			if (USE_VIRTUAL_STOPS)

			{

				VirtualStopsDriver("clear", ticket);

			}



			expirationWorker.RemoveExpiration(ticket);

		}

		

		break;

	}

	

	OnTrade();



	return true;

}



template<typename DT1, typename DT2>

bool CompareValues(string sign, DT1 v1, DT2 v2)

{

	     if (sign == ">") return(v1 > v2);

	else if (sign == "<") return(v1 < v2);

	else if (sign == ">=") return(v1 >= v2);

	else if (sign == "<=") return(v1 <= v2);

	else if (sign == "==") return(v1 == v2);

	else if (sign == "!=") return(v1 != v2);

	else if (sign == "x>") return(v1 > v2);

	else if (sign == "x<") return(v1 < v2);



	return false;

}



string CurrentSymbol(string symbol = "")

{

   static string memory = "";



	// Set

   if (symbol != "")

	{

		memory = symbol;

	}

	// Get

	else if (memory == "")

	{

		memory = Symbol();

	}



   return memory;

}



ENUM_TIMEFRAMES CurrentTimeframe(ENUM_TIMEFRAMES tf=-1)

{

   static ENUM_TIMEFRAMES memory=0;

   if (tf>=0) {memory=tf;}

   return(memory);

}



double CustomPoint(string symbol)

{

	static string symbols[];

	static double points[];

	static string last_symbol = "-";

	static double last_point  = 0;

	static int last_i         = 0;

	static int size           = 0;



	//-- variant A) use the cache for the last used symbol

	if (symbol == last_symbol)

	{

		return last_point;

	}



	//-- variant B) search in the array cache

	int i			= last_i;

	int start_i	= i;

	bool found	= false;



	if (size > 0)

	{

		while (true)

		{

			if (symbols[i] == symbol)

			{

				last_symbol	= symbol;

				last_point	= points[i];

				last_i		= i;



				return last_point;

			}



			i++;



			if (i >= size)

			{

				i = 0;

			}

			if (i == start_i) {break;}

		}

	}



	//-- variant C) add this symbol to the cache

	i		= size;

	size	= size + 1;



	ArrayResize(symbols, size);

	ArrayResize(points, size);



	symbols[i]	= symbol;

	points[i]	= 0;

	last_symbol	= symbol;

	last_i		= i;



	//-- unserialize rules from FXD_POINT_FORMAT_RULES

	string rules[];

	StringExplode(",", POINT_FORMAT_RULES, rules);



	int rules_count = ArraySize(rules);



	if (rules_count > 0)

	{

		string rule[];



		for (int r = 0; r < rules_count; r++)

		{

			StringExplode("=", rules[r], rule);



			//-- a single rule must contain 2 parts, [0] from and [1] to

			if (ArraySize(rule) != 2) {continue;}



			double from = StringToDouble(rule[0]);

			double to	= StringToDouble(rule[1]);



			//-- "to" must be a positive number, different than 0

			if (to <= 0) {continue;}



			//-- "from" can be a number or a string

			// a) string

			if (from == 0 && StringLen(rule[0]) > 0)

			{

				string s_from = rule[0];

				int pos       = StringFind(s_from, "?");



				if (pos < 0) // ? not found

				{

					if (StringFind(symbol, s_from) == 0) {points[i] = to;}

				}

				else if (pos == 0) // ? is the first symbol => match the second symbol

				{

					if (StringFind(symbol, StringSubstr(s_from, 1), 3) == 3)

					{

						points[i] = to;

					}

				}

				else if (pos > 0) // ? is the second symbol => match the first symbol

				{

					if (StringFind(symbol, StringSubstr(s_from, 0, pos)) == 0)

					{

						points[i] = to;

					}

				}

			}



			// b) number

			if (from == 0) {continue;}



			if (SymbolInfoDouble(symbol, SYMBOL_POINT) == from)

			{

				points[i] = to;

			}

		}

	}



	if (points[i] == 0)

	{

		points[i] = SymbolInfoDouble(symbol, SYMBOL_POINT);

	}



	last_point = points[i];



	return last_point;

}



bool DeleteOrder(ulong ticket, color arrowcolor=clrNONE)

{

   while(true)

   {

      MqlTradeRequest request;

      MqlTradeResult result;

      MqlTradeCheckResult check_result;

      ZeroMemory(request);

      ZeroMemory(result);

      ZeroMemory(check_result);

   

      request.order=ticket;

      request.action=TRADE_ACTION_REMOVE;

      request.comment="Pending order canceled";

   

      if (!OrderCheck(request,check_result))  {

         Print("OrderCheck() failed: "+(string)check_result.comment+" ("+(string)check_result.retcode+")");

         return false;

      }

      

      bool success = OrderSend(request,result);

      

      //-- error check --------------------------------------------------

      if (!success || result.retcode!=TRADE_RETCODE_DONE)

      {

         string errmsgpfx="Delete order error";

         int erraction=CheckForTradingError(result.retcode, errmsgpfx);

         switch(erraction)

         {

            case 0: break;    // no error

            case 1: continue; // overcomable error

            case 2: break;    // fatal error

         }

         return(false);

      }

      

      //-- finish work --------------------------------------------------

      if (result.retcode==TRADE_RETCODE_DONE)

      {

         //== Wait until MT5 updates it's cache

         int w;

         for (w=0; w<5000; w++)

         {

            if (!OrderSelect(ticket)) {break;}

            Sleep(1);

         }

         if (w==5000) {

            Print("Check error: Delete order");  

         }

         if (OrderSelect(ticket)) {

            Print("Something went wrong with the order");

            return false;

         }

      }

		

		if (success==true) {

         if (USE_VIRTUAL_STOPS) {

            VirtualStopsDriver("clear",ticket);

         }

         //RegisterEvent("trade");

         //return(true);

      }

		

      break;

   }

   OnTrade();

   return(true);

}



string DoubleToStr(double d, int dig){return(DoubleToString(d,dig));}



void DrawSpreadInfo()

{

   static bool allow_draw = true;

   if (allow_draw==false) {return;}

   if (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) {allow_draw=false;} // Allowed to draw only once in testing mode



   static bool passed         = false;

   static double max_spread   = 0;

   static double min_spread   = EMPTY_VALUE;

   static double avg_spread   = 0;

   static double avg_add      = 0;

   static double avg_cnt      = 0;



   double custom_point = CustomPoint(Symbol());

   double current_spread = 0;

   if (custom_point > 0) {

      current_spread = (SymbolInfoDouble(Symbol(),SYMBOL_ASK)-SymbolInfoDouble(Symbol(),SYMBOL_BID))/custom_point;

   }

   if (current_spread > max_spread) {max_spread = current_spread;}

   if (current_spread < min_spread) {min_spread = current_spread;}

   

   avg_cnt++;

   avg_add     = avg_add + current_spread;

   avg_spread  = avg_add / avg_cnt;



   int x=0; int y=0;

   string name;



   // create objects

   if (passed == false)

   {

      passed=true;

      

      name="fxd_spread_current_label";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+1);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+1);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 18);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkOrange);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "Spread:");

      }

      name="fxd_spread_max_label";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+148);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+17);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "max:");

      }

      name="fxd_spread_avg_label";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+148);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+9);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkOrange);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "avg:");

      }

      name="fxd_spread_min_label";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+148);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+1);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "min:");

      }

      name="fxd_spread_current";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+93);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+1);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 18);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkOrange);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "0");

      }

      name="fxd_spread_max";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+173);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+17);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "0");

      }

      name="fxd_spread_avg";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+173);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+9);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkOrange);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "0");

      }

      name="fxd_spread_min";

      if (ObjectFind(0, name)==-1) {

         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+173);

         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y+1);

         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);

         ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);

         ObjectSetString(0, name, OBJPROP_FONT, "Arial");

         ObjectSetString(0, name, OBJPROP_TEXT, "0");

      }

   }

   

   ObjectSetString(0, "fxd_spread_current", OBJPROP_TEXT, DoubleToStr(current_spread,2));

   ObjectSetString(0, "fxd_spread_max", OBJPROP_TEXT, DoubleToStr(max_spread,2));

   ObjectSetString(0, "fxd_spread_avg", OBJPROP_TEXT, DoubleToStr(avg_spread,2));

   ObjectSetString(0, "fxd_spread_min", OBJPROP_TEXT, DoubleToStr(min_spread,2));

}



string DrawStatus(string text="")

{

   static string memory;

   if (text=="") {

      return(memory);

   }

   

   static bool passed = false;

   int x=210; int y=0;

   string name;



   //-- draw the objects once

   if (passed == false)

   {

      passed = true;

      name="fxd_status_title";

      ObjectCreate(0,name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0,name, OBJPROP_BACK, false);

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

      ObjectSetInteger(0,name, OBJPROP_XDISTANCE, x);

      ObjectSetInteger(0,name, OBJPROP_YDISTANCE, y+17);

      ObjectSetString(0,name, OBJPROP_TEXT, "Status");

      ObjectSetString(0,name, OBJPROP_FONT, "Arial");

      ObjectSetInteger(0,name, OBJPROP_FONTSIZE, 7);

      ObjectSetInteger(0,name, OBJPROP_COLOR, clrGray);

      

      name="fxd_status_text";

      ObjectCreate(0,name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0,name, OBJPROP_BACK, false);

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);

      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);

      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

      ObjectSetInteger(0,name, OBJPROP_XDISTANCE, x+2);

      ObjectSetInteger(0,name, OBJPROP_YDISTANCE, y+1);

      ObjectSetString(0,name, OBJPROP_FONT, "Arial");

      ObjectSetInteger(0,name, OBJPROP_FONTSIZE, 12);

      ObjectSetInteger(0,name, OBJPROP_COLOR, clrAqua);

   }



   //-- update the text when needed

   if (text != memory) {

      memory=text;

      ObjectSetString(0,"fxd_status_text", OBJPROP_TEXT, text);

   }

   

   return(text);

}



double DynamicLots(string symbol, string mode="balance", double value=0, double sl=0, string align="align")

{

   double size=0;

   double LotStep=SymbolLotStep(symbol);

   double LotSize=SymbolLotSize(symbol);

   double MinLots=SymbolMinLot(symbol);

   double MaxLots=SymbolMaxLot(symbol);

   double TickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);

   double margin_required=0;

   bool ocm = OrderCalcMargin(ORDER_TYPE_BUY,symbol,1,ask(symbol),margin_required); // This is the MODE_MARGINREQUIRED analog in MQL5

   //if (value>MaxLots) {value=value/LotSize;} // Money-to-Lot conversion

   

        if (mode=="fixed" || mode=="lots") {size=value;}

   else if (mode=="block-equity")     {size=(value/100)*AccountEquity()/margin_required;}

   else if (mode=="block-balance")    {size=(value/100)*AccountBalance()/margin_required;}

   else if (mode=="block-freemargin") {size=(value/100)*AccountFreeMargin()/margin_required;}

   else if (mode=="equity")     {size=(value/100)*AccountEquity()/(LotSize*TickValue);}

   else if (mode=="balance")    {size=(value/100)*AccountBalance()/(LotSize*TickValue);}

   else if (mode=="freemargin") {size=(value/100)*AccountFreeMargin()/(LotSize*TickValue);}

   else if (mode=="equityRisk") {size=((value/100)*AccountEquity())/(sl*TickValue*PipValue(symbol));}

   else if (mode=="balanceRisk"){size=((value/100)*AccountBalance())/(sl*TickValue*PipValue(symbol));}

   else if (mode=="freemarginRisk") {size=((value/100)*AccountFreeMargin())/(sl*TickValue*PipValue(symbol));}

   else if (mode=="fixedRisk")   {size=(value)/(sl*TickValue*PipValue(symbol));}

   else if (mode=="fixedRatio" || mode=="RJFR") { 

      /////

      // Ryan Jones Fixed Ratio MM static data

      static double RJFR_start_lots=0;

      static double RJFR_delta=0;

      static double RJFR_units=1;

      static double RJFR_target_lower=0;

      static double RJFR_target_upper=0;

      /////

      

      if (RJFR_start_lots<=0) {RJFR_start_lots=value;}

      if (RJFR_start_lots<MinLots) {RJFR_start_lots=MinLots;}

      if (RJFR_delta<=0) {RJFR_delta=sl;}

      if (RJFR_target_upper<=0) {

         RJFR_target_upper=AccountEquity()+(RJFR_units*RJFR_delta);

         Print("Fixed Ratio MM: Units=>",RJFR_units,"; Delta=",RJFR_delta,"; Upper Target Equity=>",RJFR_target_upper);

      }

      if (AccountEquity()>=RJFR_target_upper)

      {

         while(true) {

            Print("Fixed Ratio MM going up to ",(RJFR_start_lots*(RJFR_units+1))," lots: Equity is above Upper Target Equity (",AccountEquity(),">=",RJFR_target_upper,")");

            RJFR_units++;

            RJFR_target_lower=RJFR_target_upper;

            RJFR_target_upper=RJFR_target_upper+(RJFR_units*RJFR_delta);

            Print("Fixed Ratio MM: Units=>",RJFR_units,"; Delta=",RJFR_delta,"; Lower Target Equity=>",RJFR_target_lower,"; Upper Target Equity=>",RJFR_target_upper);

            if (AccountEquity()<RJFR_target_upper) {break;}

         }

      }

      else if (AccountEquity()<=RJFR_target_lower)

      {

         while(true) {

         if (AccountEquity()>RJFR_target_lower) {break;}

            if (RJFR_units>1) {         

               Print("Fixed Ratio MM going down to ",(RJFR_start_lots*(RJFR_units-1))," lots: Equity is below Lower Target Equity | ", AccountEquity()," <= ",RJFR_target_lower,")");

               RJFR_target_upper=RJFR_target_lower;

               RJFR_target_lower=RJFR_target_lower-((RJFR_units-1)*RJFR_delta);

               RJFR_units--;

               Print("Fixed Ratio MM: Units=>",RJFR_units,"; Delta=",RJFR_delta,"; Lower Target Equity=>",RJFR_target_lower,"; Upper Target Equity=>",RJFR_target_upper);

            } else {break;}

         }

      }

      size=RJFR_start_lots*RJFR_units;

   }

		

	if (size==EMPTY_VALUE) {size=0;}

   

   static bool alert_min_lots=false;

   if (size<MinLots && alert_min_lots==false) {alert_min_lots=true;

      Alert("You want to trade ",size," lot, but your broker's minimum is ",MinLots," lot. The trade/order will continue with ",MinLots," lot instead of ",size," lot. The same rule will be applied for next trades/orders with desired lot size lower than the minimum. You will not see this message again until you restart the program.");

   }



   size=MathRound(size/LotStep)*LotStep;

   

   if (align=="align") {

      if (size<MinLots) {size=MinLots;}

      if (size>MaxLots) {size=MaxLots;}

   }

   

   return (size);

}



string ErrorMessage(int error_code=-1)

{

	string e = "";

	if (error_code<0) {error_code=GetLastError();}

	



	switch(error_code)

	{

		//--- success

		case 0: return("The operation completed successfully");

		

		//--- Runtime

		case 4001: e = "Unexpected internal error"; break;

		case 4002: e = "Wrong parameter in the inner call of the client terminal function"; break;

		case 4003: e = "Wrong parameter when calling the system function"; break;

		case 4004: e = "Not enough memory to perform the system function"; break;

		case 4005: e = "The structure contains objects of strings and/or dynamic arrays and/or structure of such objects and/or classes"; break;

		case 4006: e = "Array of a wrong type, wrong size, or a damaged object of a dynamic array"; break;

		case 4007: e = "Not enough memory for the relocation of an array, or an attempt to change the size of a static array"; break;

		case 4008: e = "Not enough memory for the relocation of string"; break;

		case 4009: e = "Not initialized string"; break;

		case 4010: e = "Invalid date and/or time"; break;

		case 4011: e = "Requested array size exceeds 2 GB"; break;

		case 4012: e = "Wrong pointer"; break;

		case 4013: e = "Wrong type of pointer"; break;

		case 4014: e = "System function is not allowed to call"; break;

		case 4015: e = "The names of the dynamic and the static resource match"; break;

		case 4016: e = "Resource with this name has not been found in EX5"; break;

		case 4017: e = "Unsupported resource type or its size exceeds 16 Mb"; break;

		case 4018: e = "The resource name exceeds 63 characters"; break;

		

		//-- Charts

		case 4101: e = "Wrong chart ID"; break;

		case 4102: e = "Chart does not respond"; break;

		case 4103: e = "Chart not found"; break;

		case 4104: e = "No Expert Advisor in the chart that could handle the event"; break;

		case 4105: e = "Chart opening error"; break;

		case 4106: e = "Failed to change chart symbol and period"; break;

		case 4107: e = "Wrong parameter for timer"; break;

		case 4108: e = "Failed to create timer"; break;

		case 4109: e = "Wrong chart property ID"; break;

		case 4110: e = "Error creating screenshots"; break;

		case 4111: e = "Error navigating through chart"; break;

		case 4112: e = "Error applying template"; break;

		case 4113: e = "Subwindow containing the indicator was not found"; break;

		case 4114: e = "Error adding an indicator to chart"; break;

		case 4115: e = "Error deleting an indicator from the chart"; break;

		case 4116: e = "Indicator not found on the specified chart"; break;



		//-- Graphical Objects

		case 4201: e = "Error working with a graphical object"; break;

		case 4202: e = "Graphical object was not found"; break;

		case 4203: e = "Wrong ID of a graphical object property"; break;

		case 4204: e = "Unable to get date corresponding to the value"; break;

		case 4205: e = "Unable to get value corresponding to the date"; break;



		//-- Market Info

		case 4301: e = "Unknown symbol"; break;

		case 4302: e = "Symbol is not selected in MarketWatch"; break;

		case 4303: e = "Wrong identifier of a symbol property"; break;

		case 4304: e = "Time of the last tick is not known (no ticks)"; break;

		case 4305: e = "Error adding or deleting a symbol in MarketWatch"; break;



		//-- History Access

		case 4401: e = "Requested history not found"; break;

		case 4402: e = "Wrong ID of the history property"; break;



		//-- Global Variables

		case 4501: e = "Global variable of the client terminal is not found"; break;

		case 4502: e = "Global variable of the client terminal with the same name already exists"; break;

		case 4510: e = "Email sending failed"; break;

		case 4511: e = "Sound playing failed"; break;

		case 4512: e = "Wrong identifier of the program property"; break;

		case 4513: e = "Wrong identifier of the terminal property"; break;

		case 4514: e = "File sending via ftp failed"; break;

		case 4515: e = "Failed to send a notification"; break;

		case 4516: e = "Invalid parameter for sending a notification - an empty string or NULL has been passed to the SendNotification() function"; break;

		case 4517: e = "Wrong settings of notifications in the terminal (ID is not specified or permission is not set)"; break;

		case 4518: e = "Too frequent sending of notifications"; break;



		//-- Custom Indicator Buffers

		case 4601: e = "Not enough memory for the distribution of indicator buffers"; break;

		case 4602: e = "Wrong indicator buffer index"; break;



		//-- Custom Indicator Properties

		case 4603: e = "Wrong ID of the custom indicator property"; break;



		//-- Account

		case 4701: e = "Wrong account property ID"; break;

		case 4751: e = "Wrong trade property ID"; break;

		case 4752: e = "Trading by Expert Advisors prohibited"; break;

		case 4753: e = "Position not found"; break;

		case 4754: e = "Order not found"; break;

		case 4755: e = "Deal not found"; break;

		case 4756: e = "Trade request sending failed"; break;



		//-- Indicators

		case 4801: e = "Unknown symbol"; break;

		case 4802: e = "Indicator cannot be created"; break;

		case 4803: e = "Not enough memory to add the indicator"; break;

		case 4804: e = "The indicator cannot be applied to another indicator"; break;

		case 4805: e = "Error applying an indicator to chart"; break;

		case 4806: e = "Requested data not found"; break;

		case 4807: e = "Wrong indicator handle"; break;

		case 4808: e = "Wrong number of parameters when creating an indicator"; break;

		case 4809: e = "No parameters when creating an indicator"; break;

		case 4810: e = "The first parameter in the array must be the name of the custom indicator"; break;

		case 4811: e = "Invalid parameter type in the array when creating an indicator"; break;

		case 4812: e = "Wrong index of the requested indicator buffer"; break;



		//-- Depth of Market

		case 4901: e = "Depth Of Market can not be added"; break;

		case 4902: e = "Depth Of Market can not be removed"; break;

		case 4903: e = "The data from Depth Of Market can not be obtained"; break;

		case 4904: e = "Error in subscribing to receive new data from Depth Of Market"; break;



		//-- File Operations

		case 5001: e = "More than 64 files cannot be opened at the same time"; break;

		case 5002: e = "Invalid file name"; break;

		case 5003: e = "Too long file name"; break;

		case 5004: e = "File opening error"; break;

		case 5005: e = "Not enough memory for cache to read"; break;

		case 5006: e = "File deleting error"; break;

		case 5007: e = "A file with this handle was closed, or was not opening at all"; break;

		case 5008: e = "Wrong file handle"; break;

		case 5009: e = "The file must be opened for writing"; break;

		case 5010: e = "The file must be opened for reading"; break;

		case 5011: e = "The file must be opened as a binary one"; break;

		case 5012: e = "The file must be opened as a text"; break;

		case 5013: e = "The file must be opened as a text or CSV"; break;

		case 5014: e = "The file must be opened as CSV"; break;

		case 5015: e = "File reading error"; break;

		case 5016: e = "String size must be specified, because the file is opened as binary"; break;

		case 5017: e = "A text file must be for string arrays, for other arrays - binary"; break;

		case 5018: e = "This is not a file, this is a directory"; break;

		case 5019: e = "File does not exist"; break;

		case 5020: e = "File can not be rewritten"; break;

		case 5021: e = "Wrong directory name"; break;

		case 5022: e = "Directory does not exist"; break;

		case 5023: e = "This is a file, not a directory"; break;

		case 5024: e = "The directory cannot be removed"; break;

		case 5025: e = "Failed to clear the directory (probably one or more files are blocked and removal operation failed)"; break;

		case 5026: e = "Failed to write a resource to a file"; break;



		//-- String Casting

		case 5030: e = "No date in the string"; break;

		case 5031: e = "Wrong date in the string"; break;

		case 5032: e = "Wrong time in the string"; break;

		case 5033: e = "Error converting string to date"; break;

		case 5034: e = "Not enough memory for the string"; break;

		case 5035: e = "The string length is less than expected"; break;

		case 5036: e = "Too large number, more than ULONG_MAX"; break;

		case 5037: e = "Invalid format string"; break;

		case 5038: e = "Amount of format specifiers more than the parameters"; break;

		case 5039: e = "Amount of parameters more than the format specifiers"; break;

		case 5040: e = "Damaged parameter of string type"; break;

		case 5041: e = "Position outside the string"; break;

		case 5042: e = "0 added to the string end, a useless operation"; break;

		case 5043: e = "Unknown data type when converting to a string"; break;

		case 5044: e = "Damaged string object"; break;



		//-- Operations with Arrays

		case 5050: e = "Copying incompatible arrays. String array can be copied only to a string array, and a numeric array - in numeric array only"; break;

		case 5051: e = "The receiving array is declared as AS_SERIES, and it is of insufficient size"; break;

		case 5052: e = "Too small array, the starting position is outside the array"; break;

		case 5053: e = "An array of zero length"; break;

		case 5054: e = "Must be a numeric array"; break;

		case 5055: e = "Must be a one-dimensional array"; break;

		case 5056: e = "Timeseries cannot be used"; break;

		case 5057: e = "Must be an array of type double"; break;

		case 5058: e = "Must be an array of type float"; break;

		case 5059: e = "Must be an array of type long"; break;

		case 5060: e = "Must be an array of type int"; break;

		case 5061: e = "Must be an array of type short"; break;

		case 5062: e = "Must be an array of type char"; break;

		

		//-- Operations with OpenCL

		case 5100: e = "OpenCL functions are not supported on this computer"; break;

		case 5101: e = "Internal error occurred when running OpenCL"; break;

		case 5102: e = "Invalid OpenCL handle"; break;

		case 5103: e = "Error creating the OpenCL context"; break;

		case 5104: e = "Failed to create a run queue in OpenCL"; break;

		case 5105: e = "Error occurred when compiling an OpenCL program"; break;

		case 5106: e = "Too long kernel name (OpenCL kernel)"; break;

		case 5107: e = "Error creating an OpenCL kernel"; break;

		case 5108: e = "Error occurred when setting parameters for the OpenCL kernel"; break;

		case 5109: e = "OpenCL program runtime error"; break;

		case 5110: e = "Invalid size of the OpenCL buffer"; break;

		case 5111: e = "Invalid offset in the OpenCL buffer"; break;

		case 5112: e = "Failed to create an OpenCL buffer"; break;

		

		//-- Operations with WebRequest

		case 5200: e = "Invalid URL"; break;

		case 5201: e = "Failed to connect to specified URL"; break;

		case 5202: e = "Timeout exceeded"; break;

		case 5203: e = "HTTP request failed"; break;



		//-- trading errors

		case 10004: e = "Requote occured"; break;

		case 10006: e = "Order is not accepted by the server"; break;

		case 10007: e = "Request canceled by trader"; break;

		case 10010: e = "Only part of the request was completed"; break;

		case 10011: e = "Request processing error"; break;

		case 10012: e = "Request canceled by timeout"; break;

		case 10013: e = "Invalid request"; break;

		case 10014: e = "Invalid volume"; break;

		case 10015: e = "Invalid price"; break;

		case 10016: e = "Invalid SL or TP"; break;

		case 10017: e = "Trading is disabled"; break;

		case 10018: e = "Market is closed"; break;

		case 10019: e = "Not enough money to trade"; break;

		case 10020: e = "Prices changed"; break;

		case 10021: e = "There are no quotes to process the request"; break;

		case 10022: e = "Invalid expiration date in the order request"; break;

		case 10023: e = "Order state changed"; break;

		case 10024: e = "Too frequent requests"; break;

		case 10025: e = "No changes in request"; break;

		case 10026: e = "Autotrading is disabled by the server"; break;

		case 10027: e = "Autotrading is disabled by the client terminal"; break;

		case 10028: e = "Request locked for processing"; break;

		case 10029: e = "Order or trade frozen"; break;

		case 10030: e = "Invalid order filling type"; break;

		case 10031: e = "No connection with the trade server"; break;

		case 10032: e = "Operation is allowed only for live accounts"; break;

		case 10033: e = "The number of pending orders has reached the limit"; break;

		case 10034: e = "The volume of orders and trades for the symbol has reached the limit"; break;

		case 10035: e = "Incorrect or prohibited order type"; break;

		case 10036: e = "Position with the specified POSITION_IDENTIFIER has already been closed"; break;

		case 10038: e = "A close volume exceeds the current position volume"; break;

		case 10039: e = "A close order already exists for a specified position"; break;

		//-- User-Defined Errors

		case 65536: e = "User defined errors"; break;

		default:	e = "Unknown error";

	}



	StringConcatenate(e, e," (",error_code,")");

	

	return e;

}



datetime ExpirationTime(string mode="GTC",int days=0, int hours=0, int minutes=0, datetime custom=0)

{

	datetime now        = TimeCurrent();

   datetime expiration = now;



	     if (mode == "GTC" || mode == "") {expiration = 0;}

	else if (mode == "today")             {expiration = (datetime)(MathFloor((now + 86400.0) / 86400.0) * 86400.0);}

	else if (mode == "specified")

	{

		expiration = 0;



		if ((days + hours + minutes) > 0)

		{

			expiration = now + (86400 * days) + (3600 * hours) + (60 * minutes);

		}

	}

	else

	{

		if (custom <= now)

		{

			if (custom < 31557600)

			{

				custom = now + custom;

			}

			else

			{

				custom = 0;

			}

		}



		expiration = custom;

	}



	return expiration;

}



ENUM_ORDER_TYPE_TIME ExpirationTypeByTime(string symbol, datetime expiration)

{

	datetime now                   = TimeCurrent();

	ENUM_ORDER_TYPE_TIME type_time = ORDER_TIME_GTC;



	// Detect Type Time

	if (expiration == 0 || expiration <= now)

	{

		type_time = ORDER_TIME_GTC;

	}

	else if (expiration == (datetime)(MathFloor((now + 86400.0) / 86400.0) * 86400.0))

	{

		type_time = ORDER_TIME_DAY;

	}

	else

	{

		type_time = ORDER_TIME_SPECIFIED;

	}



	// What if certain Type Time is not allowed?

	if (type_time == ORDER_TIME_GTC && !IsExpirationTypeAllowed(symbol, SYMBOL_EXPIRATION_GTC))

	{

		type_time = ORDER_TIME_DAY;

	}

	

	if (type_time == ORDER_TIME_DAY && !IsExpirationTypeAllowed(symbol, SYMBOL_EXPIRATION_DAY))

	{

		type_time = ORDER_TIME_SPECIFIED;

	}



	// Return Type Time

	return type_time;

}



class ExpirationWorker

{

private:

	struct CachedItems

	{

		long ticket;

		datetime expiration;

	};



	CachedItems cachedItems[];

	long chartID;

	string chartObjectPrefix;

	string chartObjectSuffix;



	template<typename T>

	void ArrayClone(T &dest[], T &src[])

	{

		int size = ArraySize(src);

		ArrayResize(dest, size);



		for (int i = 0; i < size; i++)

		{

			dest[i] = src[i];

		}

	}



	void InitialDiscovery()

	{

		ArrayResize(cachedItems, 0);



		int total = PositionsTotal();



		for (int index = 0; index <= total; index++)

		{

			long ticket = GetTicketByIndex(index);



			if (ticket == 0) continue;



			datetime expiration = GetExpirationFromObject(ticket);



			if (expiration > 0)

			{

				SetExpirationInCache(ticket, expiration);

			}

		}

	}



	long GetTicketByIndex(int index)

	{

		return (long)PositionGetTicket(index);

	}



	datetime GetExpirationFromObject(long ticket)

	{

		datetime expiration = (datetime)0;

		

		string objectName = chartObjectPrefix + IntegerToString(ticket) + chartObjectSuffix;



		if (ObjectFind(chartID, objectName) == chartID)

		{

			expiration = (datetime)ObjectGetInteger(chartID, objectName, OBJPROP_TIME);

		}



		return expiration;

	}



	bool RemoveExpirationObject(long ticket)

	{

		bool success      = false;

		string objectName = "";



		objectName = chartObjectPrefix + IntegerToString(ticket) + chartObjectSuffix;

		success    = ObjectDelete(chartID, objectName);



		return success;

	}



	void RemoveExpirationFromCache(long ticket)

	{

		int size = ArraySize(cachedItems);

		CachedItems newItems[];

		int newSize = 0;

		bool itemRemoved = false;



		for (int i = 0; i < size; i++)

		{

			if (cachedItems[i].ticket == ticket)

			{

				itemRemoved = true;

			}

			else

			{

				newSize++;

				ArrayResize(newItems, newSize);

				newItems[newSize - 1].ticket     = cachedItems[i].ticket;

				newItems[newSize - 1].expiration = cachedItems[i].expiration;

			}

		}



		if (itemRemoved) ArrayClone(cachedItems, newItems);

	}



	void SetExpirationInCache(long ticket, datetime expiration)

	{

		bool alreadyExists = false;

		int size           = ArraySize(cachedItems);



		for (int i = 0; i < size; i++)

		{

			if (cachedItems[i].ticket == ticket)

			{

				cachedItems[i].expiration = expiration;

				alreadyExists = true;

				break;

			}

		}



		if (alreadyExists == false)

		{

			ArrayResize(cachedItems, size + 1);

			cachedItems[size].ticket     = ticket;

			cachedItems[size].expiration = expiration;

		}

	}



	bool SetExpirationInObject(long ticket, datetime expiration)

	{

		if (!PositionSelectByTicket(ticket)) return false;



		string objectName = chartObjectPrefix + IntegerToString(ticket) + chartObjectSuffix;

		double price      = OrderOpenPrice();



		if (ObjectFind(chartID, objectName) == chartID)

		{

			ObjectSetInteger(chartID, objectName, OBJPROP_TIME, expiration);

			ObjectSetDouble(chartID, objectName, OBJPROP_PRICE, price);

		}

		else

		{

			ObjectCreate(chartID, objectName, OBJ_ARROW, 0, expiration, price);

		}



		ObjectSetInteger(chartID, objectName, OBJPROP_ARROWCODE, 77);

		ObjectSetInteger(chartID, objectName, OBJPROP_HIDDEN, true);

		ObjectSetInteger(chartID, objectName, OBJPROP_ANCHOR, ANCHOR_TOP);

		ObjectSetInteger(chartID, objectName, OBJPROP_COLOR, clrRed);

		ObjectSetInteger(chartID, objectName, OBJPROP_SELECTABLE, false);

		ObjectSetInteger(chartID, objectName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);

		ObjectSetString(chartID, objectName, OBJPROP_TEXT, TimeToString(expiration));



		return true;

	}

	

	bool TradeExists(long ticket)

	{

		bool exists  = false;



		for (int i = 0; i < PositionsTotal(); i++)

		{

			long positionTicket = (long)PositionGetTicket(i);



			if (!positionTicket) continue;



			if (positionTicket == ticket)

			{

				exists = true;

				break;

			}

		}



		return exists;

	}



public:

	// Default constructor

	ExpirationWorker()

	{

		chartID           = 0;

		chartObjectPrefix = "#";

		chartObjectSuffix = " Expiration Marker";



		InitialDiscovery();

	}



	void SetExpiration(long ticket, datetime expiration)

	{

		if (expiration <= 0)

		{

			RemoveExpiration(ticket);

		}

		else

		{

			SetExpirationInObject(ticket, expiration);

			SetExpirationInCache(ticket, expiration);

		}

	}



	datetime GetExpiration(long ticket)

	{

		datetime expiration = (datetime)0;

		int size            = ArraySize(cachedItems);



		for (int i = 0; i < size; i++)

		{

			if (cachedItems[i].ticket == ticket)

			{

				expiration = cachedItems[i].expiration;

				break;

			}

		}



		return expiration;

	}



	void RemoveExpiration(long ticket)

	{

		RemoveExpirationObject(ticket);

		RemoveExpirationFromCache(ticket);

	}



	void Run()

	{

		int count = ArraySize(cachedItems);



		if (count > 0)

		{

			datetime timeNow = TimeCurrent();



			for (int i = 0; i < count; i++)

			{

				if (timeNow >= cachedItems[i].expiration)

				{

					long ticket           = cachedItems[i].ticket;

					bool removeExpiration = false;



					if (TradeExists(ticket))

					{

						if (CloseTrade(ticket))

						{

							Print("close #", ticket, " by expiration");

							removeExpiration = true;

						}

					}

					else

					{

						removeExpiration = true;

					}



					if (removeExpiration)

					{

						RemoveExpiration(ticket);



						// Removing expiration causes change in the size of the cache,

						// so reset of the size and one step back of the index is needed

						count = ArraySize(cachedItems);

						i--;

					}

				}

			}

		}

	}

};



ExpirationWorker expirationWorker;



bool FilterOrderBy(

	string group_mode    = "all",

	string group         = "0",

	string market_mode   = "all",

	string market        = "",

	string BuysOrSells   = "both",

	string LimitsOrStops = "",

	int unused           = 0, // for MQL4 compatibility

	bool onTrade         = false

) {

	//-- db

	static string markets[];

	static string market0	= "-";

	static int markets_size = 0;

	

	static string groups[];

	static string group0	  = "-";

	static int groups_size = 0;

	

	//-- local variables

	bool type_pass	  = false;

	bool market_pass = false;

	bool group_pass  = false;



	int i;

	long type;

	ulong magic_number;

	string symbol;

	

	// Trades

	if (onTrade == false)

	{

		type         = OrderType();

		magic_number = OrderMagicNumber();

		symbol       = OrderSymbol();

	}

	else

	{

		type         = e_attrType();

		magic_number = e_attrMagicNumber();

		symbol       = e_attrSymbol();

	}

	

	// Trades && History trades

	if (LimitsOrStops == "")

	{

		if (

				(BuysOrSells == "both"  && (type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL))

			|| (BuysOrSells == "buys"  && type == ORDER_TYPE_BUY)

			|| (BuysOrSells == "sells" && type == ORDER_TYPE_SELL)

			)

		{

			type_pass = true;

		}

	}

	// Pending orders

	else

	{

		if (

				(BuysOrSells == "both" && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP))

			||	(BuysOrSells == "buys" && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP))

			|| (BuysOrSells == "sells" && (type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP))

			)

		{

			if (

					(LimitsOrStops == "both" && (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT))

				||	(LimitsOrStops == "stops" && (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP))

				|| (LimitsOrStops == "limits" && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT))	

				)

			{

				type_pass = true;

			}

		}

	}

	if (type_pass == false) {return false;}

	

	//-- check group

	if (group_mode == "group")

	{

		if (group == "")

		{

			if (magic_number == MagicStart)

			{

				group_pass = true;

			}

		}

		else

		{

			if (group0 != group)

			{

				group0 = group;

				StringExplode(",", group, groups);

				groups_size = ArraySize(groups);



				for(i = 0; i < groups_size; i++)

				{

					groups[i] = StringTrim(groups[i]);



					if (groups[i] == "")

					{

						groups[i] = "0";

					}

				}

			}



			for(i = 0; i < groups_size; i++)

			{

				if (magic_number == (MagicStart + (int)groups[i]))

				{

					group_pass = true;



					break;

				}

			}

		}

	}

	else if (group_mode == "all" || (group_mode == "manual" && magic_number == 0))

	{

		group_pass = true;  

	}



	if (group_pass == false) {return false;}

	

	// check market

	if (market_mode == "all")

	{

		market_pass = true;

	}

	else

	{

		if (symbol == market)

		{

			market_pass = true;

		}

		else

		{

			if (market0 != market)

			{

				market0 = market;



				if (market == "")

				{

					markets_size = 1;

					ArrayResize(markets,1);

					markets[0] = Symbol();

				}

				else

				{

					StringExplode(",", market, markets);

					markets_size = ArraySize(markets);



					for(i = 0; i < markets_size; i++)

					{

						markets[i] = StringTrim(markets[i]);



						if (markets[i] == "")

						{

							markets[i] = Symbol();

						}

					}

				}

			}



			for(i = 0; i < markets_size; i++)

			{

				if (symbol == markets[i])

				{

					market_pass = true;



					break;

				}

			}

		}

	}



	if (market_pass == false) {return false;}

 

	return(true);

}



void GetBetTradesInfo(

	double &output[],

	string group,

	string symbol,

	int pool, // 0: try running trades first and then history trades, 1: try running only, 2: try history only

	bool findConsecutive = false

) {

	if (ArraySize(output) < 4)

	{

		ArrayResize(output, 4);

		ArrayInitialize(output, 0.0);

	}



	double lots         = output[0]; // will be the lot size of the first loaded trade

	double profitOrLoss = output[1]; // 0 is initial value, 1 is profit, -1 is loss

	double consecutive  = output[2]; // the number of consecutive profitable or losable trades

	double profit       = output[3]; // will be the profit of the first loaded trade

	bool historyTrades  = (pool == 2) ? true : false;

	

	int total = (historyTrades) ? HistoryTradesTotal() : TradesTotal();



	for (int pos = total - 1; pos >= 0; pos--)

	{

		if (

			   (!historyTrades && TradeSelectByIndex(pos, "group", group, "symbol", symbol))

			|| (historyTrades && HistoryTradeSelectByIndex(pos, "group", group, "symbol", symbol))

		) {

			if (

				((pool == 0 || pool == 1) && TimeCurrent() - OrderOpenTime() < 3) // skip for brand new trades

				||

				(

					// exclude expired pending orders

					!historyTrades

					&& OrderExpiration() > 0

					&& OrderExpiration() <= OrderCloseTime()

				)

			) {

				continue;

			}



			if (lots == 0.0)

			{

				lots = OrderLots();

			}



			profit = OrderClosePrice() - OrderOpenPrice();

			profit = NormalizeDouble(profit, SymbolDigits(OrderSymbol()));

			

			if (profit == 0.0)

			{

				// Consider a trade with zero profit as non existent

				continue;

			}



			if (IsOrderTypeSell())

			{

				profit = -1 * profit;

			}



			if (profitOrLoss == 0)

			{

				// We enter here only for the first trade

				profitOrLoss = (profit < 0.0) ? -1 : 1;



				consecutive++;



				if (findConsecutive == false) break;

			}

			else

			{

				// For the trades after the first one, if its profit is the opposite of profitOrLoss, we need to break

				if (

					   (profitOrLoss > 0.0 && profit < 0.0)

					|| (profitOrLoss < 0.0 && profit > 0.0)

				) {

					break;

				}



				consecutive++;

			}

		}

	}



	output[0] = lots;

	output[1] = profitOrLoss;

	output[2] = consecutive;

	output[3] = profit;

	

	if (pool == 0 && (findConsecutive || profitOrLoss == 0))

	{

		// running trades tried, continue with the history trades

		pool = 2;

		GetBetTradesInfo(output, group, symbol, pool, findConsecutive);

	}

}



bool HistoryTradeSelectByIndex(

	int index,

	string group_mode    = "all",

	string group         = "0",

	string market_mode   = "all",

	string market        = "",

	string BuysOrSells   = "both"

) {

	if (LoadHistoryTrade(index, "select_by_pos") && LoadedType() == 3)

	{

		if (FilterOrderBy(

			group_mode,

			group,

			market_mode,

			market,

			BuysOrSells)

		) {

			return true;

		}

	}



	return false;

}



int HistoryTradesTotal(datetime from_date=0, datetime to_date=0)

{

	if (to_date == 0) {to_date = TimeCurrent() + 1;}

	

	HistorySelect(from_date, to_date);

	

	SelectedHistoryFromTime(from_date);

	SelectedHistoryToTime(to_date);

	

	return HistoryDealsTotal();

}



void HistoryTradesTotalReset()

{

	if (SelectedHistoryToTime() > 0 || SelectedHistoryFromTime() > 0) {

		HistorySelect(SelectedHistoryFromTime(), SelectedHistoryToTime());

	}

}



template<typename T>

bool InArray(T &array[], T value)

{

	int size = ArraySize(array);



	if (size > 0)

	{

		for (int i = 0; i < size; i++)

		{

			if (array[i] == value)

			{

				return true;

			}

		}

	}



	return false;

}



void CheckTrailingStop(string symbol, int magic)

{

    if (!EnableTrailingStop) return;

    

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

    double pipValue = PipValue(symbol) * point;

    double trailingStep = TrailingStep * pipValue;

    double trailingStop = TrailingStop * pipValue;

    

    for(int i = PositionsTotal()-1; i >= 0; i--)

    {

        if(PositionSelectByTicket(PositionGetTicket(i)))

        {

            if(PositionGetString(POSITION_SYMBOL) == symbol && 

               PositionGetInteger(POSITION_MAGIC) == magic)

            {

                ulong ticket = PositionGetInteger(POSITION_TICKET);

                double currentSL = PositionGetDouble(POSITION_SL);

                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);

                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

                double newSL = 0;

                

                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)

                {

                    // For buy positions

                    if(currentPrice - openPrice >= trailingStep)

                    {

                        newSL = currentPrice - trailingStop;

                        if(newSL > currentSL || currentSL == 0)

                        {

                            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));

                        }

                    }

                }

                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)

                {

                    // For sell positions

                    if(openPrice - currentPrice >= trailingStep)

                    {

                        newSL = currentPrice + trailingStop;

                        if(newSL < currentSL || currentSL == 0)

                        {

                            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));

                        }

                    }

                }

            }

        }

    }

}





//+------------------------------------------------------------------+

//| Checks if the specified expiration mode is allowed               |

//+------------------------------------------------------------------+

bool IsExpirationTypeAllowed(string symbol,int exp_type)

  {

//--- Obtain the value of the property that describes allowed expiration modes

   int expiration=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);

//--- Return true, if mode exp_type is allowed

   return((expiration&exp_type)==exp_type);

  }



bool IsFillingTypeAllowed(string symbol,int fill_type)

{

//--- Obtain the value of the property that describes allowed filling modes

   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);

//--- Return true, if mode fill_type is allowed

   return((filling & fill_type)==fill_type);

}



bool IsOrderTypeSell()

{

	int loadedType = LoadedType();



	if (loadedType == 1)

	{

		if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)

		{

			return true;

		}

	}

	else if (loadedType == 3)

	{

		return (OrderType() == ORDER_TYPE_SELL);

	}

	else if (loadedType == 4)

	{

		ulong orderTicket = OrderTicket();

		

		if (

			HistoryOrderSelect(orderTicket)

			&& (

				HistoryOrderGetInteger(orderTicket, ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT

				|| HistoryOrderGetInteger(orderTicket, ORDER_TYPE) == ORDER_TYPE_SELL_STOP

			)

		) {

			return true;

		}

	}

	else if (

		OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT

		|| OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP

	) {

		return true;

	}



	return false;

}



bool LoadHistoryTrade(int index, string selectby="select_by_pos")

{

	if (selectby == "select_by_pos")

	{

		ulong ticket  = HistoryDealGetTicket(index);



		if (ticket > 0)

		{

			if (

				   //HistoryDealSelect(ticket) - commented, because it breaks HistorySelect()

				   HistoryDealGetInteger(ticket, DEAL_TYPE) < 2

				&& (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT

				)

			{

				OrderTicket(ticket);



				LoadedType(3);



				return true;

			}

		}

	}



	if (selectby == "select_by_ticket")

	{

		if (HistoryDealSelect(index))

		{

			OrderTicket(index);



			if (HistoryDealGetInteger(index, DEAL_TYPE) < 2)

			{

				LoadedType(3);



				return true;

			}

		}

	}



	return false;

}



bool LoadPendingOrder(long ticket)

{

	bool success = false;



   if (OrderSelect(ticket))

	{

		// The order could be from any type, so check the type

		// and allow only true pending orders.

		ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);



		if (

			   type == ORDER_TYPE_BUY_LIMIT

			|| type == ORDER_TYPE_SELL_LIMIT

			|| type == ORDER_TYPE_BUY_STOP

			|| type == ORDER_TYPE_SELL_STOP

		) {

			LoadedType(2);

			OrderTicket(ticket);

			success = true;

		}

	}



   return success;

}



bool LoadPosition(ulong ticket)

{

   bool success = PositionSelectByTicket(ticket);



   if (success) {

		LoadedType(1);

		OrderTicket(ticket);

	}



   return success;

}



int LoadedType(int type = 0)

{

	// 1 - position

	// 2 - pending order

	// 3 - history position

	// 4 - history pending order



	static int memory;



	if (type > 0) {memory = type;}



	return memory;

}



bool ModifyOrder(

	long ticket,

	double op,

	double sll = 0,

	double tpl = 0,

	double slp = 0,

	double tpp = 0,

	datetime exp = 0,

	color clr = clrNONE

) {

	int bs = 1;



	if (LoadedType() == 1)

	{

		if (OrderType() == POSITION_TYPE_SELL)

		{bs = -1;} // Positive when Buy, negative when Sell

	}

	else

	{

		if (

				OrderType() == ORDER_TYPE_SELL

			|| OrderType() == ORDER_TYPE_SELL_STOP

			|| OrderType() == ORDER_TYPE_SELL_LIMIT

		)

		{bs = -1;} // Positive when Buy, negative when Sell

	}



	while (true)

	{

		uint time0 = GetTickCount();

		

		if (LoadedType() == 1)

		{

			if (!PositionSelectByTicket(ticket)) {return false;}

		}

		else

		{

			if (!OrderSelect(ticket)) {return false;}

		}



		string symbol      = OrderSymbol();

		int type           = OrderType();

		int digits         = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

		double ask         = SymbolInfoDouble(symbol,SYMBOL_ASK);

		double bid         = SymbolInfoDouble(symbol,SYMBOL_BID);

		double point       = SymbolInfoDouble(symbol,SYMBOL_POINT);

		double stoplevel   = point * SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);

		double freezelevel = point * SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);



		if (OrderType() < 2) {op = OrderOpenPrice();} else {op = NormalizeDouble(op,digits);}

		

		sll = NormalizeDouble(sll,digits);

		tpl = NormalizeDouble(tpl,digits);



		if (op < 0 || op >= EMPTY_VALUE || sll < 0 || slp < 0 || tpl < 0 || tpp < 0)

		{

			break;

		}



		//-- OP -----------------------------------------------------------

		// https://book.mql4.com/appendix/limits

		if (type == ORDER_TYPE_BUY_LIMIT)

		{

			if (ask - op < stoplevel) {op = ask - stoplevel;}

			if (ask - op <= freezelevel) {op = ask - freezelevel - point;}

		}

		else if (type == ORDER_TYPE_BUY_STOP)

		{

			if (op - ask < stoplevel) {op = ask + stoplevel;}

			if (op - ask <= freezelevel) {op = ask + freezelevel + point;}

		}

		else if (type == ORDER_TYPE_SELL_LIMIT)

		{

			if (op - bid < stoplevel) {op = bid + stoplevel;}

			if (op - bid <= freezelevel) {op = bid + freezelevel + point;}

		}

		else if (type == ORDER_TYPE_SELL_STOP)

		{

			if (bid - op < stoplevel) {op = bid - stoplevel;}

			if (bid - op < freezelevel) {op = bid - freezelevel - point;}

		}



		op = NormalizeDouble(op, digits);



		//-- SL and TP ----------------------------------------------------

		double sl = 0, tp = 0, vsl = 0, vtp = 0;



		sl = AlignStopLoss(symbol, type, op, attrStopLoss(), sll, slp);



		if (sl < 0) {break;}



		tp = AlignTakeProfit(symbol, type, op, attrTakeProfit(), tpl, tpp);



		if (tp < 0) {break;}



		if (USE_VIRTUAL_STOPS)

		{

			//-- virtual SL and TP --------------------------------------------

			vsl = sl;

			vtp = tp;

			sl  = 0;

			tp  = 0;



			double askbid = ask;



			if (bs < 0) {askbid = bid;}



			if (vsl > 0 || USE_EMERGENCY_STOPS == "always")

			{

				if (EMERGENCY_STOPS_REL > 0 || EMERGENCY_STOPS_ADD > 0)

				{

					sl = vsl - EMERGENCY_STOPS_REL*MathAbs(askbid-vsl)*bs;



					if (sl <= 0) {sl = askbid;}

					sl = sl-toDigits(EMERGENCY_STOPS_ADD,symbol)*bs;

				}

			}



			if (vtp > 0 || USE_EMERGENCY_STOPS == "always")

			{

				if (EMERGENCY_STOPS_REL>0 || EMERGENCY_STOPS_ADD>0)

				{

					tp=vtp+EMERGENCY_STOPS_REL*MathAbs(vtp-askbid)*bs;



					if (tp <= 0) {tp = askbid;}



					tp = tp + toDigits(EMERGENCY_STOPS_ADD,symbol)*bs;

				}

			}



			vsl = NormalizeDouble(vsl,digits);

			vtp = NormalizeDouble(vtp,digits);

		}



		sl = NormalizeDouble(sl,digits);

		tp = NormalizeDouble(tp,digits);



		//-- modify -------------------------------------------------------

		ResetLastError();

		

		if (USE_VIRTUAL_STOPS)

		{

			if (vsl != attrStopLoss() || vtp != attrTakeProfit())

			{

				VirtualStopsDriver("set", ticket, vsl, vtp, toPips(MathAbs(op-vsl), symbol), toPips(MathAbs(vtp-op), symbol));

			}

		}

		

		bool success = false;

		

		// check if needed to modify

		if (LoadedType() == 1)

		{

			if (

				   sl == NormalizeDouble(PositionGetDouble(POSITION_SL),digits)

				&& tp == NormalizeDouble(PositionGetDouble(POSITION_TP),digits)

				&& exp == OrderExpirationTime()

			) {

				return true;

			}

		}

		else

		{

			if (

				   op == NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN),digits)

				&& sl == NormalizeDouble(OrderGetDouble(ORDER_SL),digits)

				&& tp == NormalizeDouble(OrderGetDouble(ORDER_TP),digits)

			) {

				return true;

			}

		}



		// prepare to modify

		MqlTradeRequest request;

		MqlTradeResult result;

		MqlTradeCheckResult check_result;

		ZeroMemory(request);

		ZeroMemory(result);

		ZeroMemory(check_result);



		// modify

		if (LoadedType() == 1)

		{

			// in case of position, only sl and tp are going to be modified

			request.action   = TRADE_ACTION_SLTP;

			request.symbol   = symbol;

			request.position = PositionGetInteger(POSITION_TICKET);

			request.magic    = PositionGetInteger(POSITION_MAGIC);

			request.comment  = PositionGetString(POSITION_COMMENT);

		}

		else

		{

			// in case of pending order

			request.action     = TRADE_ACTION_MODIFY;

			request.order      = ticket;

			request.price      = op;

			request.volume     = OrderGetDouble(ORDER_VOLUME_CURRENT);

			request.magic      = OrderGetInteger(ORDER_MAGIC);

			request.type_time  = ExpirationTypeByTime(symbol, exp);

			request.expiration = exp;

			request.comment    = OrderGetString(ORDER_COMMENT);



			//-- filling type

			uint filling = (uint)SymbolInfoInteger(request.symbol,SYMBOL_FILLING_MODE);



			if (filling == SYMBOL_FILLING_FOK)

			{

				request.type_filling = ORDER_FILLING_FOK;

			}

			else if (filling == SYMBOL_FILLING_IOC)

			{

				request.type_filling = ORDER_FILLING_IOC;

			}

		}

		

		request.sl = sl;

		request.tp = tp;



		if (!OrderCheck(request,check_result))

		{

			Print("OrderCheck() failed: " + (string)check_result.comment + " (" + (string)check_result.retcode + ")");



			return false;

		}



		success = OrderSend(request, result);



		//-- error check --------------------------------------------------

		if (result.retcode != TRADE_RETCODE_DONE)

		{

			string errmsgpfx = "Modify error";

			int erraction = CheckForTradingError(result.retcode, errmsgpfx);



			switch(erraction)

			{

				case 0: break;    // no error

				case 1: continue; // overcomable error

				case 2: break;    // fatal error

			}



			return false;

		}



		//-- finish work --------------------------------------------------

		if (result.retcode == TRADE_RETCODE_DONE)

		{

			//== Wait until MT5 updates its cache

			int w;



			for (w = 0; w < 5000; w++)

			{

				if (((LoadedType() == 1 && PositionSelectByTicket(ticket)) || OrderSelect(ticket)) && (sl == NormalizeDouble(OrderStopLoss(), digits) && tp == NormalizeDouble(OrderTakeProfit(), digits)))

				{

					break;

				}



				Sleep(1);

			}



			if (w == 5000)

			{

				Print("Check error: Modify order stops");  

			}



			if (!((LoadedType() == 1 && PositionSelectByTicket(ticket)) || OrderSelect(ticket)) || (sl != NormalizeDouble(OrderStopLoss(), digits) || tp != NormalizeDouble(OrderTakeProfit(), digits)))

			{

				Print("Something went wrong when trying to modify the stops");



				return false;

			}



			if (!((LoadedType() == 1 && PositionSelectByTicket(ticket)) || OrderSelect(ticket)))

			{

				return false;

			}



			OrderModified((int)ticket);

		}



		break;

	}



	OnTrade();



	return true;

}



int OCODriver()

{

	static long last_known_ticket = 0;

	static long orders1[];

	static long orders2[];

	int i, size;



	int total = OrdersTotal();



	for (int pos=total-1; pos>=0; pos--)

	{

		if (LoadPendingOrder(OrderGetTicket(pos)))

		{

			long ticket = OrderTicket();



			//-- end here if we reach the last known ticket

			if (ticket == last_known_ticket) {break;}



			//-- set the last known ticket, only if this is the first iteration

			if (pos == total-1) {

				last_known_ticket = ticket;

			}



			//-- we are searching for pending orders, skip trades

			if (OrderType() <= ORDER_TYPE_SELL) {continue;}



			//--

			if (StringSubstr(OrderComment(), 0, 5) == "[oco:")

			{

				int ticket_oco = StrToInteger(StringSubstr(OrderComment(), 5, StringLen(OrderComment())-1)); 



				bool found = false;

				size = ArraySize(orders2);

				for (i=0; i<size; i++)

				{

					if (orders2[i] == ticket_oco) {

						found = true;

						break;

					}

				}



				if (found == false) {

					ArrayResize(orders1, size+1);

					ArrayResize(orders2, size+1);

					orders1[size] = ticket_oco;

					orders2[size] = ticket;

				}

			}

		}

	}



	size = ArraySize(orders1);

	int dbremove = false;



	for (i = size - 1; i >= 0; i--)

	{

		if (LoadPendingOrder(orders1[i]) == false || OrderType() <= ORDER_TYPE_SELL)

		{

			if (LoadPendingOrder(orders2[i])) {

				if (DeleteOrder(orders2[i]))

				{

					dbremove = true;

				}

			}

			else {

				dbremove = true;

			}

			

			if (dbremove == true)

			{

				ArrayStripKey(orders1, i);

				ArrayStripKey(orders2, i);

			}

		}

	}



	size = ArraySize(orders2);

	dbremove = false;

	for (i=size-1; i>=0; i--)

	{

		if (LoadPendingOrder(orders2[i]) == false || OrderType() <= ORDER_TYPE_SELL)

		{

			if (LoadPendingOrder(orders1[i])) {

				if (DeleteOrder(orders1[i]))

				{

					dbremove = true;

				}

			}

			else {

				dbremove = true;

			}

			

			if (dbremove == true)

			{

				ArrayStripKey(orders1, i);

				ArrayStripKey(orders2, i);

			}

		}

	}



	return true;

}



bool OnTimerSet(double seconds)

{

   if (seconds<=0) {

      EventKillTimer();

   }

   else if (seconds < 1) {

      return (EventSetMillisecondTimer((int)(seconds*1000)));  

   }

   else {

      return (EventSetTimer((int)seconds));

   }

   

   return true;

}



class OnTradeEventDetector

{

private:

	//--- structures

	struct EventValues

	{

		// special fields

		string   reason,

		         detail;



		// order related fields

		long     magic,

		         ticket;

		int      type;

		datetime timeClose,

		         timeOpen,

		         timeExpiration;

		double   commission,

		         priceOpen,

		         priceClose,

		         profit,

		         stopLoss,

		         swap,

		         takeProfit,

		         volume;

		string   comment,

		         symbol;

	};



	struct Position

	{

		ENUM_POSITION_TYPE type;

		ENUM_POSITION_REASON reason;

		long     positionId,

		         magic,

		         ticket,

		         timeMs,

		         timeUpdateMs;

		datetime time,

					timeExpiration,

		         timeUpdate;

		double   priceCurrent,

		         priceOpen,

		         profit,

		         stopLoss,

		         swap,

		         takeProfit,

		         volume;

		string   externalId,

		         comment,

		         symbol;

	};



	struct PendingOrder

	{

		ENUM_ORDER_TYPE type;

		ENUM_ORDER_STATE state;

		ENUM_ORDER_TYPE_FILLING typeFilling;

		ENUM_ORDER_TYPE_TIME typeTime;

		ENUM_ORDER_REASON reason;

		long     magic,

		         positionId,

		         positionById,

		         ticket,

		         timeSetupMs,

		         timeDoneMs;

		datetime timeDone,

		         timeExpiration,

		         timeSetup;

		double   priceCurrent,

		         priceOpen,

		         priceStopLimit,

		         stopLoss,

		         takeProfit,

		         volume,

		         volumeInitial;

		string   externalId,

		         comment,

		         symbol;

	};

	

	struct PositionExpirationTimes

	{

		long ticket;

		datetime timeExpiration;

	};



	//--- variables and arrays

	bool debug;

	

	// Because we can have multiple new events at once, the idea is

	// to run the detector repeatedly until no new event is detected.

	// When this variable is true, it means that the event detection

	// is repeated. It should stop repeating when no new event is detected.

	bool isRepeat;



	int eventValuesQueueIndex;

	EventValues eventValues[];



	PendingOrder previousPendingOrders[];

	PendingOrder pendingOrders[];



	Position previousPositions[];

	Position positions[];



	PositionExpirationTimes positionExpirationTimes[];



	//--- methods



	/**

	* Like ArrayCopy(), but for any type.

	*/

	template<typename T>

	void CopyList(T &dest[], T &src[])

	{

		int size = ArraySize(src);

		ArrayResize(dest, size);



		for (int i = 0; i < size; i++)

		{

			dest[i] = src[i];

		}

	}



	/**

	* Overloaded method 1 of 2

	*/

	int MakeListOf(PendingOrder &list[])

	{

		ArrayResize(list, 0);



		int count        = OrdersTotal();

		int howManyAdded = 0;



		for (int index = 0; index < count; index++)

		{

			if (OrderGetTicket(index) <= 0) continue;



			ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);



			if (

				orderType != ORDER_TYPE_BUY_LIMIT

				&& orderType != ORDER_TYPE_SELL_LIMIT

				&& orderType != ORDER_TYPE_BUY_STOP

				&& orderType != ORDER_TYPE_SELL_STOP

				&& orderType != ORDER_TYPE_BUY_STOP_LIMIT

				&& orderType != ORDER_TYPE_SELL_STOP_LIMIT

			) {

				continue;

			}



			howManyAdded++;

			ArrayResize(list, howManyAdded);

			int i = howManyAdded - 1;



			// enum types

			list[i].type        = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

			list[i].state       = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);

			list[i].typeFilling = (ENUM_ORDER_TYPE_FILLING)OrderGetInteger(ORDER_TYPE_FILLING);

			list[i].typeTime    = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);

			list[i].reason      = (ENUM_ORDER_REASON)OrderGetInteger(ORDER_REASON);



			// long

			list[i].magic        = (long)OrderGetInteger(ORDER_MAGIC);

			list[i].positionId   = (long)OrderGetInteger(ORDER_POSITION_ID);

			list[i].positionById = (long)OrderGetInteger(ORDER_POSITION_BY_ID);

			list[i].ticket       = (long)OrderGetInteger(ORDER_TICKET);

			list[i].timeSetupMs  = (long)OrderGetInteger(ORDER_TIME_SETUP_MSC);

			list[i].timeDoneMs   = (long)OrderGetInteger(ORDER_TIME_DONE_MSC);



			// datetime

			list[i].timeDone       = (datetime)OrderGetInteger(ORDER_TIME_DONE);

			list[i].timeExpiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

			list[i].timeSetup      = (datetime)OrderGetInteger(ORDER_TIME_SETUP);



			// double

			list[i].priceCurrent   = OrderGetDouble(ORDER_PRICE_CURRENT);

			list[i].priceOpen      = OrderGetDouble(ORDER_PRICE_OPEN);

			list[i].priceStopLimit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);

			list[i].stopLoss       = OrderGetDouble(ORDER_SL);

			list[i].takeProfit     = OrderGetDouble(ORDER_TP);

			list[i].volume         = OrderGetDouble(ORDER_VOLUME_CURRENT);

			list[i].volumeInitial  = OrderGetDouble(ORDER_VOLUME_INITIAL);



			// string

			list[i].externalId = OrderGetString(ORDER_EXTERNAL_ID);

			list[i].comment    = OrderGetString(ORDER_COMMENT);

			list[i].symbol     = OrderGetString(ORDER_SYMBOL);

		}



		return howManyAdded;

	}



	/**

	* Overloaded method 2 of 2

	*/

	int MakeListOf(Position &list[])

	{

		ArrayResize(list, 0);



		int count        = PositionsTotal();

		int howManyAdded = 0;



		for (int index = 0; index < count; index++)

		{

			if (PositionGetTicket(index) <= 0) continue;



			howManyAdded++;

			ArrayResize(list, howManyAdded);

			int i = howManyAdded - 1;



			// enum types

			list[i].type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

			list[i].reason = (ENUM_POSITION_REASON)PositionGetInteger(POSITION_REASON);



			// long

			list[i].positionId   = (long)PositionGetInteger(POSITION_IDENTIFIER);

			list[i].magic        = (long)PositionGetInteger(POSITION_MAGIC);

			list[i].ticket       = (long)PositionGetInteger(POSITION_TICKET);

			list[i].timeMs       = (long)PositionGetInteger(POSITION_TIME_MSC);

			list[i].timeUpdateMs = (long)PositionGetInteger(POSITION_TIME_UPDATE_MSC);



			// datetime

			list[i].time           = (datetime)PositionGetInteger(POSITION_TIME);

			list[i].timeExpiration = (datetime)0;

			list[i].timeUpdate     = (datetime)PositionGetInteger(POSITION_TIME_UPDATE);



			// double

			list[i].priceCurrent = PositionGetDouble(POSITION_PRICE_CURRENT);

			list[i].priceOpen    = PositionGetDouble(POSITION_PRICE_OPEN);

			list[i].profit       = PositionGetDouble(POSITION_PROFIT);

			list[i].stopLoss     = PositionGetDouble(POSITION_SL);

			list[i].swap         = PositionGetDouble(POSITION_SWAP);

			list[i].takeProfit   = PositionGetDouble(POSITION_TP);

			list[i].volume       = PositionGetDouble(POSITION_VOLUME);



			// string

			list[i].externalId = PositionGetString(POSITION_EXTERNAL_ID);

			list[i].comment    = PositionGetString(POSITION_COMMENT);

			list[i].symbol     = PositionGetString(POSITION_SYMBOL);



			// extract expiration

			list[i].timeExpiration = expirationWorker.GetExpiration(list[i].ticket);



			if (USE_VIRTUAL_STOPS)

			{

				list[i].stopLoss   = VirtualStopsDriver("get sl", list[i].ticket);

				list[i].takeProfit = VirtualStopsDriver("get tp", list[i].ticket);

			}

		}



		return howManyAdded;

	}



	/**

	* This method loops through 2 lists of items and finds a difference. This difference is the event.

	* "Items" are either pending orders or positions.

	*

	* Returns true if an event is detected or false if not.

	*/

	template<typename ITEMS_TYPE> 

	bool DetectEvent(ITEMS_TYPE &previousItems[], ITEMS_TYPE &currentItems[])

	{

		ITEMS_TYPE item;

		string reason   = "";

		string detail   = "";

		int countBefore = ArraySize(previousItems);

		int countNow    = ArraySize(currentItems);



		// closed

		if (reason == "") {

			for (int index = 0; index < countBefore; index++) {

				item = FindMissingItem(previousItems, currentItems);



				if (item.ticket > 0) {

					DeleteItem(previousItems, item);

					reason = "close";



					break;

				}

			}

		}



		// new

		if (reason == "") {

			for (int index = 0; index < countNow; index++) {

				item = FindMissingItem(currentItems, previousItems);



				if (item.ticket > 0) {

					if (

						item.type < 2 // it's a running trade

						&& item.ticket != attrTicketParent(item.ticket)

					) {

						// In MQL4: When a trade is closed partially, the ticket changes.

						// The original (parent) trade is closed and a new one is created,

						// with a different ticket.

						reason = "decrement";

					}

					else {

						reason = "new";

					}



					PushItem(previousItems, item);



					break;

				}

			}

		}



		// modified

		if (reason == "") {

			if (countBefore != countNow) {

				Print("OnTrade event detector: Uncovered situation reached");

			}



			for (int index = 0; index < countNow; index++) {

				int previousIndex = -1;



				ITEMS_TYPE current = currentItems[index];

				ITEMS_TYPE previous;

				previous.ticket = 0;



				for (int j = 0; j < countBefore; j++) {

					if (current.ticket == previousItems[j].ticket) {

						previousIndex = j;

						previous = previousItems[j];



						break;

					}

				}



				if (current.ticket != previous.ticket) {

					Print("OnTrade event detector: Uncovered situation reached (2)");

				}



				if (previous.volume < current.volume) {

					previousItems[previousIndex].volume = current.volume;

					item = previousItems[previousIndex];



					reason = "increment";



					break;

				}



				if (previous.volume > current.volume) {

					previousItems[previousIndex].volume = current.volume;

					item = previousItems[previousIndex];



					reason = "decrement";



					break;

				}



				if (

					previous.stopLoss != current.stopLoss

					&& previous.takeProfit != current.takeProfit

				) {

					previousItems[previousIndex].stopLoss = current.stopLoss;

					previousItems[previousIndex].takeProfit = current.takeProfit;

					item = previousItems[previousIndex];



					reason = "modify";

					detail = "sltp";



					break;

				}

				// SL modified

				else if (previous.stopLoss != current.stopLoss) {

					previousItems[previousIndex].stopLoss = current.stopLoss;

					item = previousItems[previousIndex];



					reason = "modify";

					detail = "sl";



					break;

				}

				// TP modified

				else if (previous.takeProfit != current.takeProfit) {

					previousItems[previousIndex].takeProfit = current.takeProfit;

					item = previousItems[previousIndex];



					reason = "modify";

					detail = "tp";



					break;

				}



				if (previous.timeExpiration != current.timeExpiration) {

					previousItems[previousIndex].timeExpiration = current.timeExpiration;

					item = previousItems[previousIndex];



					reason = "modify";

					detail = "expiration";



					break;

				}

			}

		}



		if (reason == "")

		{

			return false;

		}



		UpdateValues(item, reason, detail);



		return true;

	}



	/**

	* From the source list of orders or positions, find the item that is missing

	* in the target list of orders or positions. The searching is by the item's ticket.

	*

	* If all items from the source list exist in the target list, return an empty item with ticket 0.

	* If for some item in source list there is no item in the target list, return that source item.

	*/

	template<typename T> 

	T FindMissingItem(T &source[], T &target[])

	{

		int sourceCount = ArraySize(source);

		int targetCount  = ArraySize(target);

		T item;

		item.ticket = 0;



		long ticket = 0;



		for (int i = 0; i < sourceCount; i++)

		{

			bool found = false;



			for (int j = 0; j < targetCount; j++)

			{

				if (source[i].ticket == target[j].ticket)

				{

					found = true;

					break;

				}

			}



			if (found == false)

			{

				item = source[i];

				break;

			}

		}



		return item;

	}



	/**

	* From the list of previous orders or positions, find and remove the

	* provided item.

	*/

	template<typename T> 

	bool DeleteItem(T &list[], T &item)

	{

		int listCount = ArraySize(list);

		bool removed = false;



		for (int i = 0; i < listCount; i++)

		{

			if (list[i].ticket == item.ticket) {

				ArrayStripKey(list, i);

				removed = true;



				break;

			}

		}



		return removed;

	}



	/**

	* Push a new item in the list

	*/

	template<typename T> 

	void PushItem(T &list[], T &item)

	{

		int listCount = ArraySize(list);



		ArrayResize(list, listCount + 1);



		list[listCount] = item;

	}



	/**

	* Overloaded method 1 of 2

	*/

	void UpdateValues(Position &item, string reason, string detail)

	{

		long ticket        = item.ticket;

		datetime timeOpen  = item.time;

		datetime timeClose = (datetime)0;

		double priceOpen   = item.priceOpen;

		double priceClose  = item.priceCurrent;

		double profit      = item.profit;

		double swap        = item.swap;

		double commission  = 0.0;

		double volume      = item.volume;



		if (reason == "close" || reason == "decrement")

		{

			if (HistorySelectByPosition(item.positionId))

			{

				int total = HistoryDealsTotal();



				// Fallback:

				// After reports and tests, one year after I re-wrote this class with

				// great care and tests, I noted that the last deal doesn't give us

				// proper data. It doesn't even apear as a close deal. For that

				// reason, as a second variant I'm getting data from orders

				// and the position itself.

				//

				// In the future, check if things are working normally again and remove

				// the fallback code.

				int totalOrders = HistoryOrdersTotal();



				if (total > 0)

				{

					long firstTicket = (long)HistoryDealGetTicket(0);

					long lastTicket  = (long)HistoryDealGetTicket(total - 1);

					long lastOrderTicket = (long)HistoryOrderGetTicket(totalOrders - 1);



					// Ticket is the ticket of the previous deal, the one before the last one

					ticket = (long)HistoryDealGetTicket(total - 2);



					if (HistoryDealSelect(firstTicket)) {

						priceOpen = HistoryDealGetDouble(firstTicket, DEAL_PRICE);

						timeOpen  = (datetime)HistoryDealGetInteger(firstTicket, DEAL_TIME);

					}



					if (HistoryDealSelect(lastTicket)) {

						timeClose  = (datetime)HistoryDealGetInteger(lastTicket, DEAL_TIME);

						priceClose = HistoryDealGetDouble(lastTicket, DEAL_PRICE);



						profit     = HistoryDealGetDouble(lastTicket, DEAL_PROFIT);

						swap       = HistoryDealGetDouble(lastTicket, DEAL_SWAP);

						commission = HistoryDealGetDouble(lastTicket, DEAL_COMMISSION);

						

						volume = HistoryDealGetDouble(lastTicket, DEAL_VOLUME);

					}



					// Find why the position has been closed

					if (detail == "")

					{

						if (

							item.timeExpiration > 0

							&& item.timeExpiration <= timeClose

						) {

							detail = "expiration";

						}

					}



					if (detail == "")

					{

						if (HistoryDealSelect(lastTicket)) {

							ENUM_DEAL_REASON dealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(lastTicket, DEAL_REASON);



							switch (dealReason)

							{

								case DEAL_REASON_SL: detail = "sl"; break;

								case DEAL_REASON_TP: detail = "tp"; break;

								case DEAL_REASON_SO: detail = "so"; break;

							}

						}

					}

				}

			}

		}



		int i = eventValuesQueueIndex;



		eventValues[i].reason = reason;

		eventValues[i].detail = detail;



		eventValues[i].priceClose     = priceClose;

		eventValues[i].timeClose      = timeClose;

		eventValues[i].comment        = item.comment;

		eventValues[i].commission     = commission;

		eventValues[i].timeExpiration = item.timeExpiration;

		eventValues[i].volume         = volume;

		eventValues[i].magic          = item.magic;

		eventValues[i].priceOpen      = priceOpen;

		eventValues[i].timeOpen       = timeOpen;

		eventValues[i].profit         = profit;

		eventValues[i].stopLoss       = item.stopLoss;

		eventValues[i].swap           = swap;

		eventValues[i].symbol         = item.symbol;

		eventValues[i].takeProfit     = item.takeProfit;

		eventValues[i].ticket         = ticket;

		eventValues[i].type           = item.type;



		if (debug)

		{

			PrintUpdatedValues();

		}

	}



	/**

	* Overloaded method 2 of 2

	*/

	void UpdateValues(PendingOrder &item, string reason, string detail)

	{

		datetime timeExpiration = item.timeExpiration;



		// When the lifetime of the order is ORDER_TIME_DAY,

		// the expiration (ORDER_TIME_EXPIRATION) equals to the time of opening.

		// Here we fix this.

		if (item.typeTime == ORDER_TIME_DAY)

		{

			timeExpiration = (datetime)(MathFloor(((double)item.timeSetup + 86400.0) / 86400.0) * 86400.0);

		}



		int i = eventValuesQueueIndex;



		eventValues[i].reason = reason;

		eventValues[i].detail = detail;



		eventValues[i].priceClose     = item.priceCurrent;

		eventValues[i].timeClose      = item.timeDone;

		eventValues[i].comment        = item.comment;

		eventValues[i].commission     = 0.0;

		eventValues[i].timeExpiration = timeExpiration;

		eventValues[i].volume         = item.volume;

		eventValues[i].magic          = item.magic;

		eventValues[i].priceOpen      = item.priceOpen;

		eventValues[i].timeOpen       = item.timeSetup;

		eventValues[i].profit         = 0.0;

		eventValues[i].stopLoss       = item.stopLoss;

		eventValues[i].swap           = 0.0;

		eventValues[i].symbol         = item.symbol;

		eventValues[i].takeProfit     = item.takeProfit;

		eventValues[i].ticket         = item.ticket;

		eventValues[i].type           = item.type;



		if (debug)

		{

			PrintUpdatedValues();

		}

	}



	void PrintUpdatedValues()

	{

		Print(

			" <<<\n",

			" | reason: ", e_Reason(),

			" | detail: ", e_ReasonDetail(),

			" | ticket: ", e_attrTicket(),

			" | type: ", EnumToString((ENUM_ORDER_TYPE)e_attrType()),

			"\n",

			" | openTime : ", e_attrOpenTime(),

			" | openPrice : ", e_attrOpenPrice(),

			"\n",

			" | closeTime: ", e_attrCloseTime(),

			" | closePrice: ", e_attrClosePrice(),

			"\n",

			" | volume: ", e_attrLots(),

			" | sl: ", e_attrStopLoss(),

			" | tp: ", e_attrTakeProfit(),

			" | profit: ", e_attrProfit(),

			" | swap: ", e_attrSwap(),

			" | exp: ", e_attrExpiration(),

			" | comment: ", e_attrComment(),

			"\n >>>"

		);

	}



	int AddEventValues()

	{

		eventValuesQueueIndex++;

		ArrayResize(eventValues, eventValuesQueueIndex + 1);



		return eventValuesQueueIndex;

	}



	int RemoveEventValues()

	{

		if (eventValuesQueueIndex == -1)

		{

			Print("Cannot remove event values, add them first. (in function ", __FUNCTION__, ")");

		}

		else

		{

			eventValuesQueueIndex--;

			ArrayResize(eventValues, eventValuesQueueIndex + 1);

		}



		return eventValuesQueueIndex;

	}



public:

	/**

	* Default constructor

	*/

	OnTradeEventDetector(void)

	{

		debug = false;

		isRepeat = false;

		eventValuesQueueIndex = -1;

	};



	bool Start()

	{

		AddEventValues();



		if (isRepeat == false) {

			MakeListOf(pendingOrders);

			MakeListOf(positions);

		}



		bool success = false;



		if (!success) success = DetectEvent(previousPendingOrders, pendingOrders);



		if (!success) success = DetectEvent(previousPositions, positions);



		//CopyList(previousPendingOrders, pendingOrders);

		//CopyList(previousPositions, positions);



		isRepeat = success; // Repeat until no success



		return success;

	}



	void End()

	{

		RemoveEventValues();

	}



	string EventValueReason() {return eventValues[eventValuesQueueIndex].reason;}

	string EventValueDetail() {return eventValues[eventValuesQueueIndex].detail;}



	int EventValueType() {return eventValues[eventValuesQueueIndex].type;}



	datetime EventValueTimeClose()      {return eventValues[eventValuesQueueIndex].timeClose;}

	datetime EventValueTimeOpen()       {return eventValues[eventValuesQueueIndex].timeOpen;}

	datetime EventValueTimeExpiration() {return eventValues[eventValuesQueueIndex].timeExpiration;}



	long EventValueMagic()  {return eventValues[eventValuesQueueIndex].magic;}

	long EventValueTicket() {return eventValues[eventValuesQueueIndex].ticket;}



	double EventValueCommission() {return eventValues[eventValuesQueueIndex].commission;}

	double EventValuePriceOpen()  {return eventValues[eventValuesQueueIndex].priceOpen;}

	double EventValuePriceClose() {return eventValues[eventValuesQueueIndex].priceClose;}

	double EventValueProfit()     {return eventValues[eventValuesQueueIndex].profit;}

	double EventValueStopLoss()   {return eventValues[eventValuesQueueIndex].stopLoss;}

	double EventValueSwap()       {return eventValues[eventValuesQueueIndex].swap;}

	double EventValueTakeProfit() {return eventValues[eventValuesQueueIndex].takeProfit;}

	double EventValueVolume()     {return eventValues[eventValuesQueueIndex].volume;}



	string EventValueComment() {return eventValues[eventValuesQueueIndex].comment;}

	string EventValueSymbol()  {return eventValues[eventValuesQueueIndex].symbol;}

};



OnTradeEventDetector onTradeEventDetector;



double OrderClosePrice()

{

	int type = LoadedType();



	if (type == 1)

	{

		if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)

		{

			return SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID);

		}

		else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)

		{

			return SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK);

		}

	}

	if (type == 3) {

		ulong dealTicket = OrderTicket();

		HistoryDealSelect(dealTicket);

		ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

		long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

		double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);



		HistorySelectByPosition(positionId);

		

		// Search for the first OUT deal after this one and get the price from it



		int total = HistoryDealsTotal();

	

		for (int i = total - 1; i >= 0; i--) {

			ulong ticket = HistoryDealGetTicket(i);

	

			if (ticket == dealTicket) {

				// Get the current value if the deal is the the last one

				if (i == total - 1 && PositionSelectByDeal(ticket))

				{

					if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)

					{

						price = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID);

					}

					else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)

					{

						price = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK);

					}

				}

		

				break;

			}

	

			if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {

				price = HistoryDealGetDouble(ticket, DEAL_PRICE);

			}

		}

		

		HistoryTradesTotalReset();

		

		return price;

	}

	if (type == 4) {

		// TODO: Why I used deals here?

		ulong dealTicket = OrderTicket();



		if (HistoryDealSelect(dealTicket)) {

			return HistoryDealGetDouble(dealTicket, DEAL_PRICE);

		}

	}



	return(OrderGetDouble(ORDER_PRICE_CURRENT));

}



datetime OrderCloseTime()

{

	int type = LoadedType();



	if (type == 1)

	{

		return 0;

	}



	if (type == 3)

	{

		ulong dealTicket = OrderTicket();

		HistoryDealSelect(dealTicket);

		ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

		long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

		datetime time = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);



		HistorySelectByPosition(positionId);



		// Search for the first OUT deal after this one and get the time from it



		int total = HistoryDealsTotal();



		for (int i = total - 1; i >= 0; i--) {

			ulong ticket = HistoryDealGetTicket(i);



			if (ticket == dealTicket) {

				if (i == total - 1 && PositionSelectByDeal(ticket))

				{

					time = (datetime)0;

				}



				break;

			}



			if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {

				time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

			}

		}



		HistoryTradesTotalReset();



		return time;

	}



	if (type == 4)

	{

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			return (datetime)HistoryOrderGetInteger(orderTicket, ORDER_TIME_DONE);

		}

	}

	

	return (datetime)OrderGetInteger(ORDER_TIME_DONE);

}



string OrderComment()

{

	int type = LoadedType();



	if (type == 1) {return PositionGetString(POSITION_COMMENT);}

	if (type == 3) {

		ulong ticket = OrderTicket();

		

		if (HistoryDealSelect(ticket)) {

			return HistoryOrderGetString(HistoryDealGetInteger(ticket, DEAL_POSITION_ID), ORDER_COMMENT);

		}

	}

	if (type == 4) {

		ulong ticket = OrderTicket();

		

		if (HistoryOrderSelect(ticket)) {

			return HistoryOrderGetString(ticket, ORDER_COMMENT);

		}

	}



	return OrderGetString(ORDER_COMMENT);

}



long OrderCreate(

	string   symbol     = "",

	int      type       = ORDER_TYPE_BUY,

	double   lots       = 0,

	double   op         = 0,

	double   sll        = 0,

	double   tpl        = 0,

	double   slp        = 0,

	double   tpp        = 0,

	double   slippage   = 0,

	ulong    magic      = 0,

	string   comment    = NULL,

	color    arrowcolor = clrNONE,

	datetime expiration = 0,

	bool     oco        = false

	)

{

	OnTrade(); // When position is closed by sl or tp, this event is not fired (by MetaTrader) until the end of the tick, and if a new position is opened, it will be missed. 



	uint time0 = GetTickCount(); // used to measure speed of execution of the order

	

	bool placeExpirationObject = false; // whether or not to create an object for expiration for trades



	bool closing = false;

	double lots0 = 0;

	long type0   = type;



	if (

		   (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)

		&& (type == POSITION_TYPE_BUY || type == POSITION_TYPE_SELL)

		)

	{

		if (PositionSelect(symbol))

		{

			if ((int)PositionGetInteger(POSITION_TYPE) != type)

			{

				closing = true;

			}



			lots0 = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 5);

			type0 = PositionGetInteger(POSITION_TYPE);

		}

	}



	ulong ticket = -1;



	// calculate buy/sell flag (1 when Buy or -1 when Sell)

	int bs = 1;



	if (

		   type == ORDER_TYPE_SELL

		|| type == ORDER_TYPE_SELL_STOP

		|| type == ORDER_TYPE_SELL_LIMIT

	)

	{

		bs = -1;

	}



	if (symbol == "") {symbol = Symbol();}



	lots = AlignLots(symbol, lots);



	int digits = 0;

	double ask = 0, bid = 0, point = 0, ticksize = 0;

	double sl = 0, tp = 0;

	double vsl = 0, vtp = 0;

	bool successed = false;



	//-- attempts to send position/order ---------------------------------

	while (true)

	{

		digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

		ask      = SymbolInfoDouble(symbol, SYMBOL_ASK);

		bid      = SymbolInfoDouble(symbol, SYMBOL_BID);

		point    = SymbolInfoDouble(symbol, SYMBOL_POINT);

		ticksize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);



		//- not enough money check: fix maximum possible lot by margin required, or quit

		if ((type == POSITION_TYPE_BUY || type == POSITION_TYPE_SELL) && closing == false)

		{

			double LotStep         = SymbolLotStep(symbol);

			double MinLots         = SymbolMinLot(symbol);

			double margin_required = 0;

			bool ocm               = OrderCalcMargin((ENUM_ORDER_TYPE)type, symbol, 1, SymbolInfoDouble(symbol, SYMBOL_ASK), margin_required);

			static bool not_enough_message = false;



			if (margin_required != 0)

			{

				double max_size_by_margin = AccountFreeMargin() / margin_required;

			

				if (lots > max_size_by_margin)

				{

					double lots_old = lots;

					lots = max_size_by_margin;



					if (lots < MinLots)

					{

						if (not_enough_message == false)

						{

							Print("Not enough money to trade :( The robot is still working, waiting for some funds to appear...");

						}



						not_enough_message = true;



						return -1;

					}

					else

					{

						lots = MathFloor(lots / LotStep) * LotStep;

						Print("Not enough money to trade " + DoubleToString(lots_old, 2) + ", the volume to trade will be the maximum possible of " + DoubleToString(lots, 2));

					}

				}

			}



			not_enough_message = false;

		}



		// fix the comment, because it seems that the comment is deleted if its lenght is > 31 symbols

		if (StringLen(comment) > 31)

		{

			comment = StringSubstr(comment, 0, 31);

		}



		//- expiration for trades

		if (type == POSITION_TYPE_BUY || type == POSITION_TYPE_SELL)

		{

			if (expiration > 0)

			{

				//- bo broker?

				if (

					   StringLen(symbol) > 6

					&& StringSubstr(symbol, StringLen(symbol) - 2) == "bo"

				) {

					//- convert UNIX to seconds

					if (expiration > TimeCurrent()-100)

					{

						expiration = expiration - TimeCurrent();

					}



					comment = "BO exp:" + (string)expiration;

				}

				else

				{

					// The expiration in this case is a vertical line

					// Comment doesn't always work,

					// because it changes when the trade is partially closed

					placeExpirationObject = true;

				}

			}

		}



		if (type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)

		{

			op = (bs > 0) ? ask : bid;

		}



		op  = NormalizeDouble(op, digits);

		sll = NormalizeDouble(sll, digits);

		tpl = NormalizeDouble(tpl, digits);



		if (op < 0 || op >= EMPTY_VALUE || sll < 0 || slp < 0 || tpl < 0 || tpp < 0)

		{

			break;

		}



		//-- SL and TP ----------------------------------------------------

		vsl = 0;

		vtp = 0;



		sl = AlignStopLoss(symbol, type, op, 0, NormalizeDouble(sll,digits), slp);



		if (sl < 0) {break;}



		tp = AlignTakeProfit(symbol, type, op, 0, NormalizeDouble(tpl,digits), tpp);



		if (tp < 0) {break;}



		if (USE_VIRTUAL_STOPS)

		{

			//-- virtual SL and TP --------------------------------------------

			vsl = sl;

			vtp = tp;

			sl = 0;

			tp = 0;

			

			double askbid = (bs > 0) ? ask : bid;

			

			if (vsl > 0 || USE_EMERGENCY_STOPS == "always")

			{

				if (EMERGENCY_STOPS_REL > 0 || EMERGENCY_STOPS_ADD > 0)

				{

					sl = vsl - EMERGENCY_STOPS_REL * MathAbs(askbid - vsl) * bs;



					if (sl <= 0) {sl = askbid;}



					sl = sl - toDigits(EMERGENCY_STOPS_ADD, symbol) * bs;

				}

			}



			if (vtp > 0 || USE_EMERGENCY_STOPS == "always")

			{

				if (EMERGENCY_STOPS_REL > 0 || EMERGENCY_STOPS_ADD > 0)

				{

					tp = vtp + EMERGENCY_STOPS_REL * MathAbs(vtp - askbid) * bs;



					if (tp <= 0) {tp = askbid;}



					tp = tp + toDigits(EMERGENCY_STOPS_ADD, symbol) * bs;

				}

			}



			vsl = NormalizeDouble(vsl, digits);

			vtp = NormalizeDouble(vtp, digits);

		}



		sl = NormalizeDouble(sl, digits);

		tp = NormalizeDouble(tp, digits);



		//-- send ---------------------------------------------------------

		MqlTradeRequest request;

		MqlTradeResult result;

		MqlTradeCheckResult check_result;

		ZeroMemory(request);

		ZeroMemory(result);

		ZeroMemory(check_result);



		ENUM_SYMBOL_TRADE_EXECUTION exec = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);



		//-- fix prices by ticksize

		op = MathRound(op / ticksize) * ticksize;

		sl = MathRound(sl / ticksize) * ticksize;

		tp = MathRound(tp / ticksize) * ticksize;



		request.symbol     = symbol;

		request.type       = (ENUM_ORDER_TYPE)type;

		request.volume     = lots;

		request.price      = op;

		request.deviation  = (ulong)(slippage * PipValue(symbol));

		request.sl         = sl;

		request.tp         = tp;

		request.comment    = comment;

		request.magic      = magic;

		request.type_time  = ExpirationTypeByTime(symbol, expiration);

		request.expiration = expiration;



		//-- request action

		if (type > ORDER_TYPE_SELL)

		{

			request.action = TRADE_ACTION_PENDING;

		}

		else

		{

			request.action = TRADE_ACTION_DEAL;

		}

		//-- filling type

		

		// check ORDER_FILLING_RETURN for pending orders only 

		if (type > ORDER_TYPE_SELL)

		{

			if (IsFillingTypeAllowed(symbol, ORDER_FILLING_RETURN))

				request.type_filling = ORDER_FILLING_RETURN;

			else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_FOK))

				request.type_filling = ORDER_FILLING_FOK;

			else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_IOC))

				request.type_filling = ORDER_FILLING_IOC;

		}

		else

		{

			// in case of positions I would check for SYMBOL_FILLING_ and then set ORDER_FILLING_

			// this is because it appears that IsFillingTypeAllowed() works correct with SYMBOL_FILLING_, but then the position works correctly with ORDER_FILLING_

			// FOK and IOC integer values are not the same for ORDER and SYMBOL



			if (IsFillingTypeAllowed(symbol, SYMBOL_FILLING_FOK))

				request.type_filling = ORDER_FILLING_FOK;

			else if (IsFillingTypeAllowed(symbol, SYMBOL_FILLING_IOC))

				request.type_filling = ORDER_FILLING_IOC;

			else if (IsFillingTypeAllowed(symbol, ORDER_FILLING_RETURN)) // just in case

				request.type_filling = ORDER_FILLING_RETURN;

			else

				request.type_filling = ORDER_FILLING_RETURN;

		}



		if (!OrderCheck(request,check_result))

		{

			Print("OrderCheck() failed: ", (string)check_result.comment, " (", (string)check_result.retcode, ")");



			return -1;

		}



		bool success = OrderSend(request, result);



		//-- check security flag ------------------------------------------

		if (successed == true)

		{

			Print("The program will be removed because of suspicious attempt to create a new position");

			ExpertRemove();

			Sleep(10000);



			break;

		}



		if (success) {successed = true;}



		//-- error check --------------------------------------------------

		if (

			   success == false

			|| (

				   result.retcode != TRADE_RETCODE_DONE

				&& result.retcode != TRADE_RETCODE_PLACED

				&& result.retcode != TRADE_RETCODE_DONE_PARTIAL

			)

		)

		{

			string errmsgpfx = (type > ORDER_TYPE_SELL) ? "New pending order error" : "New position error";



			int erraction = CheckForTradingError(result.retcode, errmsgpfx);



			switch (erraction)

			{

				case 0: break;    // no error

				case 1: continue; // overcomable error

				case 2: break;    // fatal error

			}



			return -1;

		}



		//-- finish work --------------------------------------------------

		if (

			   result.retcode == TRADE_RETCODE_DONE

			|| result.retcode == TRADE_RETCODE_PLACED

			|| result.retcode == TRADE_RETCODE_DONE_PARTIAL

		) {

			ticket = result.order;

			//== Whatever was created, we need to wait until MT5 updates it's cache



			//-- Synchronize: Position

			if (type <= ORDER_TYPE_SELL)

			{

				if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)

				{

					if (closing == false)

					{

						//- new position: 2 situations here - new position or add to position

						//- ... because of that we will check the lot size instead of PositionSelect

						while (true)

						{

							if (PositionSelect(symbol) && (lots0 != NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 5))) {break;}

							Sleep(10);

						}

					}

					else

					{

						//- closing position: full

						if (lots0 == NormalizeDouble(result.volume, 5))

						{

							while (true)

							{

								if (!PositionSelect(symbol)) {break;}

								Sleep(10);

							}

						}

						//- closing position: partial

						else if (lots0 > NormalizeDouble(result.volume, 5))

						{

							while (true)

							{

								if (PositionSelect(symbol) && (lots0 != NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 5))) {break;}

								Sleep(10);

							}

						}

						else if (lots0 < NormalizeDouble(result.volume, 5))

						{

						//-- position reverse

							while (true)

							{

								if (PositionSelect(symbol) && (type0 != PositionGetInteger(POSITION_TYPE))) {break;}

								Sleep(10);

							}

						}

					}

				}

				else if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)

				{

					if (closing == false)

					{

						while (true)

						{

							if (PositionSelectByTicket(ticket)) {break;}

							Sleep(10);

						}

					}

				}

			}

			//-- Synchronize: Order

			else

			{

				while (true)

				{

					if (LoadPendingOrder(result.order)) {break;}

					Sleep(10);

				}

			}



			//-- fix arrow color (it works only in visual mode)

			// TODO: this piece of code slows down the backtest for some reason

			if (0 && MQLInfoInteger(MQL_VISUAL_MODE) && arrowcolor != CLR_NONE)

			{

				if (type <= ORDER_TYPE_SELL)

				{

					uint t0 = GetTickCount();

					ENUM_OBJECT objType = (type==POSITION_TYPE_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;



					// wait for the object to be created (MQL5 is async even here)

					while(true)

					{

						int total        = ObjectsTotal(0,0,objType);

						string name      = ObjectName(0,total-1,0,objType);

						datetime objTime = (datetime)ObjectGetInteger(0,name,OBJPROP_TIME);



						if (objTime > TimeCurrent()-1)

						{

							if (StringFind(name, "#" + IntegerToString(ticket) + " ") == 0)

							{

								ObjectSetInteger(0,name,OBJPROP_COLOR,arrowcolor);

							}



							break;

						}



						if (GetTickCount() - t0 > 1000) break;

					}

				}

				else

				{

					// Pending orders don't have arrows

				}

			}

		}



		if (ticket > 0)

		{

			if (USE_VIRTUAL_STOPS)

			{

				VirtualStopsDriver("set", ticket, vsl, vtp, toPips(MathAbs(op-vsl), symbol), toPips(MathAbs(vtp-op), symbol));

			}



			//-- show some info

			double slip = 0;



			if (LoadPosition(ticket))

			{

				if (placeExpirationObject)

				{

					expirationWorker.SetExpiration(ticket, expiration);

				}



				if (

					   !MQLInfoInteger(MQL_TESTER)

					&& !MQLInfoInteger(MQL_VISUAL_MODE)

					&& !MQLInfoInteger(MQL_OPTIMIZATION)

				) {

					slip = OrderOpenPrice() - op;



					Print(

						"Operation details: Speed ",

						(GetTickCount() - time0),

						" ms | Slippage ",

						DoubleToStr(toPips(slip, symbol), 1),

						" pips"

					);

				}

			}

			

			//-- fix stops in case of slippage

			if (

				   !MQLInfoInteger(MQL_TESTER)

				&& !MQLInfoInteger(MQL_VISUAL_MODE)

				&& !MQLInfoInteger(MQL_OPTIMIZATION)

			) {



				slip = NormalizeDouble(OrderOpenPrice(), digits) - NormalizeDouble(op, digits);



				if (slip != 0 && (OrderStopLoss() != 0 || OrderTakeProfit() != 0))

				{

					Print("Correcting stops because of slippage...");



					sl = OrderStopLoss();

					tp = OrderTakeProfit();



					if (sl != 0 || tp != 0)

					{

						if (sl != 0) {sl = NormalizeDouble(OrderStopLoss() + slip, digits);}

						if (tp != 0) {tp = NormalizeDouble(OrderTakeProfit() + slip, digits);}



						ModifyOrder(ticket, OrderOpenPrice(), sl, tp, 0, 0);

					}

				}

			}



			//RegisterEvent("trade");



			break;

		}



		break;

	}



	if (oco == true && ticket > 0)

	{

		if (USE_VIRTUAL_STOPS)

		{

			sl = vsl;

			tp = vtp;

		}



		sl = (sl > 0) ? NormalizeDouble(MathAbs(op-sl), digits) : 0;

		tp = (tp > 0) ? NormalizeDouble(MathAbs(op-tp), digits) : 0;

		

		int typeoco = type;



		if (typeoco == ORDER_TYPE_BUY_STOP)

		{

			typeoco = ORDER_TYPE_SELL_STOP;

			op = bid - MathAbs(op-ask);

		}

		else if (typeoco == ORDER_TYPE_BUY_LIMIT)

		{

			typeoco = ORDER_TYPE_SELL_LIMIT;

			op = bid + MathAbs(op-ask);

		}

		else if (typeoco == ORDER_TYPE_SELL_STOP)

		{

			typeoco = ORDER_TYPE_BUY_STOP;

			op = ask + MathAbs(op-bid);

		}

		else if (typeoco == ORDER_TYPE_SELL_LIMIT)

		{

			typeoco = ORDER_TYPE_BUY_LIMIT;

			op = ask - MathAbs(op-bid);

		}



		if (typeoco == ORDER_TYPE_BUY_STOP || typeoco == ORDER_TYPE_BUY_LIMIT)

		{

			sl = (sl > 0) ? op - sl : 0;

			tp = (tp > 0) ? op + tp : 0;

		}

		else {

			sl = (sl > 0) ? op + sl : 0;

			tp = (tp > 0) ? op - tp : 0;

		}



		comment = "[oco:" + (string)ticket + "]";



		OrderCreate(

			symbol,

			typeoco,

			lots,

			op,

			sl,

			tp,

			0,

			0,

			slippage,

			magic,

			comment,

			arrowcolor,

			expiration,

			false

		);

	}



	OnTrade();



	return (long)ticket;

}



datetime OrderExpiration()

{

	return OrderExpirationTime();

}



datetime OrderExpirationTime()

{

	int LoadedType = LoadedType();



	if (LoadedType == 1) return expirationWorker.GetExpiration(PositionGetInteger(POSITION_TICKET));

	if (LoadedType == 2) return (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);



	return 0;

}



double OrderLots()

{

	int type = LoadedType();

	double lots = 0;



	if (type == 1) {

		lots = PositionGetDouble(POSITION_VOLUME);

	}

	else if (type == 3) {

		// Calculate lots as the difference between the intial lots

		// and the lots of all



		if (HistoryDealSelect(OrderTicket())) {

			long positionId = HistoryDealGetInteger(OrderTicket(), DEAL_POSITION_ID);

	

			HistorySelectByPosition(positionId);

	

			int total = HistoryDealsTotal();

	

			lots = 0.0;

	

			for (int i = 0; i < total; i++) {

				ulong ticket = HistoryDealGetTicket(i);

				ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

				double dealVolume = HistoryDealGetDouble(ticket, DEAL_VOLUME);

	

				if (entry == DEAL_ENTRY_IN) {

					lots += dealVolume;

				}

				else {

					// If the last deal is the final close, it's size would be the same as the

					// calculated lots. In this case, skip, otherwise the final lots will be 0.

					if (NormalizeDouble(dealVolume, 4) < NormalizeDouble(lots, 4)) {

						lots -= dealVolume;

					}

				}

			}

		}



		HistoryTradesTotalReset();

	}

	else if (type == 4) {

		ulong ticket = OrderTicket();

		

		if (HistoryOrderSelect(ticket)) {

			lots = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);

		}

	}

	else {lots = OrderGetDouble(ORDER_VOLUME_CURRENT);}



	return NormalizeDouble(lots, 2);

}



int OrderMagicNumber()

{

	int type = LoadedType();



	if (type == 1) {return (int)PositionGetInteger(POSITION_MAGIC);}

	if (type == 3) {

		ulong dealTicket = OrderTicket();

		

		if (HistoryDealSelect(dealTicket)) {

			ulong orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);

			

			if (HistoryOrderSelect(orderTicket)) {

				return (int)HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);

			}

		}

	}

	if (type == 4) {

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			return (int)HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);

		}

	}



	return (int)OrderGetInteger(ORDER_MAGIC);

}



bool OrderModified(ulong ticket = 0, string action = "set")

{

	static ulong memory[];



	if (ticket == 0)

	{

		ticket = OrderTicket();

		action = "get";

	}

	else if (ticket > 0 && action != "clear")

	{

		action = "set";

	}



	bool modified_status = InArray(memory, ticket);

	

	if (action == "get")

	{

		return modified_status;

	}

	else if (action == "set")

	{

		ArrayEnsureValue(memory, ticket);



		return true;

	}

	else if (action == "clear")

	{

		ArrayStripValue(memory, ticket);



		return true;

	}



	return false;

}



double OrderOpenPrice()

{

	double op  = 0.0;

	int type   = LoadedType();

	int digits = (int)SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);



	if (type == 1)

	{

		op = PositionGetDouble(POSITION_PRICE_OPEN);

	}

	else if (type == 3)

	{

		// Get the value from the very first deal in the position

		

		ulong dealTicket = OrderTicket();



		if (HistoryDealSelect(dealTicket)) {

			ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);



			HistorySelectByPosition(positionId);



			ulong ticket = HistoryDealGetTicket(0);



			op = HistoryDealGetDouble(ticket, DEAL_PRICE);

		}



		HistoryTradesTotalReset();

	}

	else if (type == 4)

	{

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			op = HistoryOrderGetDouble(orderTicket, ORDER_PRICE_OPEN);

		}

	}

   else

   {

   	op = OrderGetDouble(ORDER_PRICE_OPEN);

   }



	return NormalizeDouble(op, digits);

}



datetime OrderOpenTime()

{

	datetime time = 0;

	int type      = LoadedType();



	if (type == 1)

	{

		time = (datetime)PositionGetInteger(POSITION_TIME);

	}

	else if (type == 3)

	{

		// Get the value from the very first deal in the position



		ulong dealTicket = OrderTicket();



		if (HistoryDealSelect(dealTicket)) {

			ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

	

			HistorySelectByPosition(positionId);

	

			ulong ticket = HistoryDealGetTicket(0);

			

			time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

		}

		

		HistoryTradesTotalReset();

	}

	else if (type == 4)

	{

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			time = (datetime)HistoryOrderGetInteger(orderTicket, ORDER_TIME_SETUP);

		}

	}

	else

	{

		time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);

	}

	

	return time;

}



double OrderStopLoss()

{

	int type = LoadedType();



	if (type == 1) {return PositionGetDouble(POSITION_SL);}

	if (type == 3) {

		ulong dealTicket = OrderTicket();

		

		if (HistoryDealSelect(dealTicket)) {

			return HistoryDealGetDouble(dealTicket, DEAL_SL);

		}

	}

	if (type == 4) {

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			return HistoryOrderGetDouble(orderTicket, ORDER_SL);

		}

	}



	return OrderGetDouble(ORDER_SL);

}



string OrderSymbol()

{

	int type = LoadedType();



	if (type == 1) {return PositionGetString(POSITION_SYMBOL);}

	if (type == 3) {

		ulong dealTicket = OrderTicket();

		

		if (HistoryDealSelect(dealTicket)) {

			return HistoryDealGetString(dealTicket, DEAL_SYMBOL);

		}

	}

	if (type == 4) {

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			return HistoryOrderGetString(orderTicket, ORDER_SYMBOL);

		}

	}



	return OrderGetString(ORDER_SYMBOL);

}



double OrderTakeProfit()

{

	int type = LoadedType();



	if (type == 1) {return PositionGetDouble(POSITION_TP);}

	if (type == 3) {

		ulong dealTicket = OrderTicket();

		

		if (HistoryDealSelect(dealTicket)) {

			return HistoryDealGetDouble(dealTicket, DEAL_TP);

		}

	}

	if (type == 4) {

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			return HistoryOrderGetDouble(orderTicket, ORDER_TP);

		}

	}



	return OrderGetDouble(ORDER_TP);

}



long OrderTicket(long ticket = 0)

{

	static long memory = 0;



	if (ticket > 0) {memory = ticket;}



	return memory;

}



int OrderType()

{

	int type = LoadedType();



	if (type == 1) {return (int)PositionGetInteger(POSITION_TYPE);}

	if (type == 2) {return (int)OrderGetInteger(ORDER_TYPE);}

	if (type == 3)

	{

		ulong dealTicket = OrderTicket();

		int orderType = -1;



		if (HistoryDealSelect(dealTicket)) {

			long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);



			HistorySelectByPosition(positionId);

	

			ulong firstDealTicket = HistoryDealGetTicket(0);



			orderType = (int)HistoryDealGetInteger(firstDealTicket, DEAL_TYPE);

		}



		HistoryTradesTotalReset();



		return orderType;

	}

	if (type == 4) {

		ulong orderTicket = OrderTicket();

		

		if (HistoryOrderSelect(orderTicket)) {

			return (int)HistoryOrderGetInteger(OrderTicket(),ORDER_TYPE);

		}

	}



	return (int)OrderGetInteger(ORDER_TYPE);

}



bool PendingOrderSelectByTicket(ulong ticket)

{

	bool success = OrderSelect(ticket);



	if (success) {

		LoadedType(2);

		OrderTicket(ticket);

	}



	return success;

}



double PipValue(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return CustomPoint(symbol) / SymbolInfoDouble(symbol, SYMBOL_POINT);

}



bool PositionSelectByDeal(ulong dealTicket)

{

	bool success = false;



	if (HistoryDealSelect(dealTicket)) {

		long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

		

		if (positionId)

		{

			int total = PositionsTotal();

			

			for (int i = total - 1; i >= 0; i--)

			{

				if (PositionGetTicket(i))

				{

					if (PositionGetInteger(POSITION_IDENTIFIER) == positionId)

					{

						success = true;

	

						break;

					}

				}

			}

		}

	}



	return success;

}



int SecondsFromComponents(double days, double hours, double minutes, int seconds)

{

	int retval =

		86400 * (int)MathFloor(days)

		+ 3600 * (int)(MathFloor(hours) + (24 * (days - MathFloor(days))))

		+ 60 * (int)(MathFloor(minutes) + (60 * (hours - MathFloor(hours))))

		+ (int)((double)seconds + (60 * (minutes - MathFloor(minutes))));



	return retval;

}



datetime SelectedHistoryFromTime(datetime setTime = -1)

{

	static datetime time;

	

	if (setTime > -1)

	{

		time = setTime;

	}

	

	return time;

}



datetime SelectedHistoryToTime(datetime setTime = -1)

{

	static datetime time;

	

	if (setTime > -1)

	{

		time = setTime;

	}

	

	return time;

}



long SellNow(

	string symbol,

	double lots,

	double sll,

	double tpl,

	double slp,

	double tpp,

	double slippage = 0,

	int magic = 0,

	string comment = "",

	color arrowcolor = clrNONE,

	datetime expiration = 0

	)

{

	return OrderCreate(

		symbol,

		POSITION_TYPE_SELL,

		lots,

		0,

		sll,

		tpl,

		slp,

		tpp,

		slippage,

		magic,

		comment,

		arrowcolor,

		expiration

	);

}



int StrToInteger(string value)

{

	return (int)StringToInteger(value);

}



template<typename T>

void StringExplode(string delimiter, string inputString, T &output[])

{

	int begin   = 0;

	int end     = 0;

	int element = 0;

	int length  = StringLen(inputString);

	int length_delimiter = StringLen(delimiter);

	T empty_val  = (typename(T) == "string") ? (T)"" : (T)0;



	if (length > 0)

	{

		while (true)

		{

			end = StringFind(inputString, delimiter, begin);



			ArrayResize(output, element + 1);

			output[element] = empty_val;

	

			if (end != -1)

			{

				if (end > begin)

				{

					output[element] = (T)StringSubstr(inputString, begin, end - begin);

				}

			}

			else

			{

				output[element] = (T)StringSubstr(inputString, begin, length - begin);

				break;

			}

			

			begin = end + 1 + (length_delimiter - 1);

			element++;

		}

	}

	else

	{

		ArrayResize(output, 1);

		output[element] = empty_val;

	}

}



template<typename T>

string StringImplode(string delimeter, T &array[])

{

   string retval = "";

	int size      = ArraySize(array);



   for (int i = 0; i < size; i++)

	{

      StringConcatenate(retval, retval, (string)array[i], delimeter);

   }



   return StringSubstr(retval, 0, (StringLen(retval) - StringLen(delimeter)));

}



string StringTrim(string text)

{

	StringTrimRight(text);

	StringTrimLeft(text);



	return text;

}



double SymbolAsk(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return SymbolInfoDouble(symbol, SYMBOL_ASK);

}



double SymbolBid(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return SymbolInfoDouble(symbol, SYMBOL_BID);

}



int SymbolDigits(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

}



double SymbolLotSize(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

}



double SymbolLotStep(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

}



double SymbolMaxLot(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

}



double SymbolMinLot(string symbol)

{

	if (symbol == "") symbol = Symbol();



	return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

}



double TicksData(string symbol = "", int type = 0, int shift = 0)

{

	static bool collecting_ticks = false;

	static string symbols[];

	static int zero_sid[];

	static double memoryASK[][100];

	static double memoryBID[][100];



	int sid = 0, size = 0, i = 0, id = 0;

	double ask = 0, bid = 0, retval = 0;

	bool exists = false;



	if (ArraySize(symbols) == 0)

	{

		ArrayResize(symbols, 1);

		ArrayResize(zero_sid, 1);

		ArrayResize(memoryASK, 1);

		ArrayResize(memoryBID, 1);



		symbols[0] = _Symbol;

	}



	if (type > 0 && shift > 0)

	{

		collecting_ticks = true;

	}



	if (collecting_ticks == false)

	{

		if (type > 0 && shift == 0)

		{

			// going to get ticks

		}

		else

		{

			return 0;

		}

	}



	if (symbol == "") symbol = _Symbol;



	if (type == 0)

	{

		exists = false;

		size   = ArraySize(symbols);



		if (size == 0) {ArrayResize(symbols, 1);}



		for (i=0; i<size; i++)

		{

			if (symbols[i] == symbol)

			{

				exists = true;

				sid    = i;

				break;

			}

		}



		if (exists == false)

		{

			int newsize = ArraySize(symbols) + 1;



			ArrayResize(symbols, newsize);

			symbols[newsize-1] = symbol;



			ArrayResize(zero_sid, newsize);

			ArrayResize(memoryASK, newsize);

			ArrayResize(memoryBID, newsize);



			sid=newsize;

		}



		if (sid >= 0)

		{

			ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

			bid = SymbolInfoDouble(symbol, SYMBOL_BID);



			if (bid == 0 && MQLInfoInteger(MQL_TESTER))

			{

				Print("Ticks data collector error: " + symbol + " cannot be backtested. Only the current symbol can be backtested. The EA will be terminated.");

				ExpertRemove();

			}



			if (

				   symbol == _Symbol

				|| ask != memoryASK[sid][0]

				|| bid != memoryBID[sid][0]

			)

			{

				memoryASK[sid][zero_sid[sid]] = ask;

				memoryBID[sid][zero_sid[sid]] = bid;

				zero_sid[sid]                 = zero_sid[sid] + 1;



				if (zero_sid[sid] == 100)

				{

					zero_sid[sid] = 0;

				}

			}

		}

	}

	else

	{

		if (shift <= 0)

		{

			if (type == SYMBOL_ASK)

			{

				return SymbolInfoDouble(symbol, SYMBOL_ASK);

			}

			else if (type == SYMBOL_BID)

			{

				return SymbolInfoDouble(symbol, SYMBOL_BID); 

			}

			else

			{

				double mid = ((SymbolInfoDouble(symbol, SYMBOL_ASK) + SymbolInfoDouble(symbol, SYMBOL_BID)) / 2);



				return mid;

			}

		}

		else

		{

			size = ArraySize(symbols);



			for (i = 0; i < size; i++)

			{

				if (symbols[i] == symbol)

				{

					sid = i;

				}

			}



			if (shift < 100)

			{

				id = zero_sid[sid] - shift - 1;



				if(id < 0) {id = id + 100;}



				if (type == SYMBOL_ASK)

				{

					retval = memoryASK[sid][id];



					if (retval == 0)

					{

						retval = SymbolInfoDouble(symbol, SYMBOL_ASK);

					}

				}

				else if (type == SYMBOL_BID)

				{

					retval = memoryBID[sid][id];



					if (retval == 0)

					{

						retval = SymbolInfoDouble(symbol, SYMBOL_BID);

					}

				}

			}

		}

	}



	return retval;

}



int TicksPerSecond(bool get_max = false, bool set = false)

{

	static datetime time0 = 0;

	static int ticks      = 0;

	static int tps        = 0;

	static int tpsmax     = 0;



	datetime time1 = TimeLocal();



	if (set == true)

	{

		if (time1 > time0)

		{

			if (time1 - time0 > 1)

			{

				tps = 0;

			}

			else

			{

				tps = ticks;

			}



			time0 = time1;

			ticks = 0;

		}



		ticks++;



		if (tps > tpsmax) {tpsmax = tps;}

	}



	if (get_max)

	{

		return tpsmax;

	}



	return tps;

}



datetime TimeAtStart(string cmd = "server")

{

	static datetime local  = 0;

	static datetime server = 0;



	if (cmd == "local")

	{

		return local;

	}

	else if (cmd == "server")

	{

		return server;

	}

	else if (cmd == "set")

	{

		local  = TimeLocal();

		server = TimeCurrent();

	}



	return 0;

}



int TimeDay(datetime time)

{

	MqlDateTime tm;

   TimeToStruct(time,tm);

   return(tm.day);

}



int TimeDayOfWeek(datetime time)

{

   MqlDateTime tm;

   TimeToStruct(time,tm);

   return(tm.day_of_week);

}



datetime TimeFromComponents(

	int time_src = 0,

	int    y = 0,

	int    m = 0,

	double d = 0,

	double h = 0,

	double i = 0,

	int    s = 0

) {

	MqlDateTime tm;

	int offset = 0;



	if (time_src == 0) {

		TimeCurrent(tm);

	}

	else if (time_src == 1) {

		TimeLocal(tm); 

		offset = (int)(TimeLocal() - TimeCurrent());

	}

	else if (time_src == 2) {

		TimeGMT(tm);

		offset = (int)(TimeGMT() - TimeCurrent());

	}



	if (y > 0)

	{

		if (y < 100) {y = 2000 + y;}

		tm.year = y;

	}

	if (m > 0) {tm.mon = m;}

	if (d > 0) {tm.day = (int)MathFloor(d);}



	tm.hour = (int)(MathFloor(h) + (24 * (d - MathFloor(d))));

	tm.min  = (int)(MathFloor(i) + (60 * (h - MathFloor(h))));

	tm.sec  = (int)((double)s + (60 * (i - MathFloor(i))));

	

	datetime time = StructToTime(tm) - offset;



	return time;

}



int TimeHour(datetime time)

{

	MqlDateTime tm;

	TimeToStruct(time,tm);



	return tm.hour;

}



int TimeMinute(datetime time)

{

	MqlDateTime tm;

	TimeToStruct(time,tm);

	

	return tm.min;

}



int TimeMonth(datetime time)

{

	MqlDateTime tm;

	TimeToStruct(time,tm);



	return tm.mon;

}



int TimeSeconds(datetime time)

{

	MqlDateTime tm;

	TimeToStruct(time,tm);



	return tm.sec;

}



int TimeYear(datetime time)

{

   MqlDateTime tm;

	TimeToStruct(time,tm);



	return tm.year;

}



bool TradeSelectByIndex(

	int index,

	string group_mode    = "all",

	string group         = "0",

	string market_mode   = "all",

	string market        = "",

	string BuysOrSells   = "both"

) {

	if (LoadPosition(PositionGetTicket(index)))

	{

		if (FilterOrderBy(

			group_mode,

			group,

			market_mode,

			market,

			BuysOrSells)

			)

		{

			return true;

		}

	}



	return false;

}



bool TradeSelectByTicket(ulong ticket)

{

	if (LoadPosition(ticket) && OrderType() < 2)

	{

		return true;

	}



	return false;

}



int TradesTotal()

{

	return PositionsTotal();

}



double VirtualStopsDriver(

	string command = "",

	ulong ti       = 0,

	double sl      = 0,

	double tp      = 0,

	double slp     = 0,

	double tpp     = 0

)

{

	static bool initialized     = false;

	static string name          = "";

	static string loop_name[2]  = {"sl", "tp"};

	static color  loop_color[2] = {DeepPink, DodgerBlue};

	static double loop_price[2] = {0, 0};

	static ulong mem_to_ti[]; // tickets

	static int mem_to[];      // timeouts

	static bool trade_pass = false;

	int i = 0;



	// Are Virtual Stops even enabled?

	if (!USE_VIRTUAL_STOPS)

	{

		return 0;

	}

	

	if (initialized == false || command == "initialize")

	{

		initialized = true;

	}



	// Listen

	if (command == "" || command == "listen")

	{

		int total     = ObjectsTotal(0, -1, OBJ_HLINE);

		int length    = 0;

		color clr     = clrNONE;

		int sltp      = 0;

		ulong ticket  = 0;

		double level  = 0;

		double askbid = 0;

		int polarity  = 0;

		string symbol = "";



		for (i = total - 1; i >= 0; i--)

		{

			name = ObjectName(0, i, -1, OBJ_HLINE); // for example: #1 sl



			if (StringSubstr(name, 0, 1) != "#")

			{

				continue;

			}



			length = StringLen(name);



			if (length < 5)

			{

				continue;

			}



			clr = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);



			if (clr != loop_color[0] && clr != loop_color[1])

			{

				continue;

			}



			string last_symbols = StringSubstr(name, length-2, 2);



			if (last_symbols == "sl")

			{

				sltp = -1;

			}

			else if (last_symbols == "tp")

			{

				sltp = 1;

			}

			else

			{

				continue;	

			}



			ulong ticket0 = StringToInteger(StringSubstr(name, 1, length - 4));



			// prevent loading the same ticket number twice in a row

			if (ticket0 != ticket)

			{

				ticket = ticket0;



				if (TradeSelectByTicket(ticket))

				{

					symbol     = OrderSymbol();

					polarity   = (OrderType() == 0) ? 1 : -1;

					askbid   = (OrderType() == 0) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);

					

					trade_pass = true;

				}

				else

				{

					trade_pass = false;

				}

			}



			if (trade_pass)

			{

				level    = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);



				if (level > 0)

				{

					// polarize levels

					double level_p  = polarity * level;

					double askbid_p = polarity * askbid;



					if (

						   (sltp == -1 && (level_p - askbid_p) >= 0) // sl

						|| (sltp == 1 && (askbid_p - level_p) >= 0)  // tp

					)

					{

						//-- Virtual Stops SL Timeout

						if (

							   (VIRTUAL_STOPS_TIMEOUT > 0)

							&& (sltp == -1 && (level_p - askbid_p) >= 0) // sl

						)

						{

							// start timeout?

							int index = ArraySearch(mem_to_ti, ticket);



							if (index < 0)

							{

								int size = ArraySize(mem_to_ti);

								ArrayResize(mem_to_ti, size+1);

								ArrayResize(mem_to, size+1);

								mem_to_ti[size] = ticket;

								mem_to[size]    = (int)TimeLocal();



								Print(

									"#",

									ticket,

									" timeout of ",

									VIRTUAL_STOPS_TIMEOUT,

									" seconds started"

								);



								return 0;

							}

							else

							{

								if (TimeLocal() - mem_to[index] <= VIRTUAL_STOPS_TIMEOUT)

								{

									return 0;

								}

							}

						}



						if (CloseTrade(ticket))

						{

							// check this before deleting the lines

							//OnTradeListener();



							// delete objects

							ObjectDelete(0, "#" + (string)ticket + " sl");

							ObjectDelete(0, "#" + (string)ticket + " tp");

						}

					}

					else

					{

						if (VIRTUAL_STOPS_TIMEOUT > 0)

						{

							i = ArraySearch(mem_to_ti, ticket);



							if (i >= 0)

							{

								ArrayStripKey(mem_to_ti, i);

								ArrayStripKey(mem_to, i);

							}

						}

					}

				}

			}

			else if (

					!PendingOrderSelectByTicket(ticket)

				|| OrderCloseTime() > 0 // in case the order has been closed

			)

			{

				ObjectDelete(0, name);

			}

			else

			{

				PendingOrderSelectByTicket(ticket);

			}

		}

	}

	// Get SL or TP

	else if (

		ti > 0

		&& (

			   command == "get sl"

			|| command == "get tp"

		)

	)

	{

		double value = 0;



		name = "#" + IntegerToString(ti) + " " + StringSubstr(command, 4, 2);



		if (ObjectFind(0, name) > -1)

		{

			value = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);

		}



		return value;

	}

	// Set SL and TP

	else if (

		ti > 0

		&& (

			   command == "set"

			|| command == "modify"

			|| command == "clear"

			|| command == "partial"

		)

	)

	{

		loop_price[0] = sl;

		loop_price[1] = tp;



		for (i = 0; i < 2; i++)

		{

			name = "#" + IntegerToString(ti) + " " + loop_name[i];

			

			if (loop_price[i] > 0)

			{

				// 1) create a new line

				if (ObjectFind(0, name) == -1)

				{

						 ObjectCreate(0, name, OBJ_HLINE, 0, 0, loop_price[i]);

					ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

					ObjectSetInteger(0, name, OBJPROP_COLOR, loop_color[i]);

					ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);

					ObjectSetString(0, name, OBJPROP_TEXT, name + " (virtual)");

				}

				// 2) modify existing line

				else

				{

					ObjectSetDouble(0, name, OBJPROP_PRICE, 0, loop_price[i]);

				}

			}

			else

			{

				// 3) delete existing line

				ObjectDelete(0, name);

			}

		}



		// print message

		if (command == "set" || command == "modify")

		{

			Print(

				command,

				" #",

				IntegerToString(ti),

				": virtual sl ",

				DoubleToStr(sl, (int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS)),

				" tp ",

				DoubleToStr(tp,(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS))

			);

		}



		return 1;

	}



	return 1;

}



double ask(string symbol = NULL)

{

	return SymbolInfoDouble(symbol, SYMBOL_ASK);

}



double attrStopLoss()

{

	if (USE_VIRTUAL_STOPS)

	{

		return VirtualStopsDriver("get sl", OrderTicket());

	}



	return OrderStopLoss();

}



double attrTakeProfit()

{

	if (USE_VIRTUAL_STOPS)

	{

		return VirtualStopsDriver("get tp", OrderTicket());

	}



   return OrderTakeProfit();

}



/**

* Get the parent position ticket when the current position

* was created as "add to volume" child.

* In other cases, return the input ticket.

*/

long attrTicketParent(long ticket)

{

	long parentTicket = 0;



	if (PositionSelectByTicket(ticket)) {

		string comment = PositionGetString(POSITION_COMMENT);

		int tagPos     = StringFind(comment, "[p=");

		

		if (tagPos >= 0) {

			string tag   = StringSubstr(comment, tagPos);

			tag          = StringSubstr(tag, 0, StringFind(tag, "]") + 1);

			parentTicket = StringToInteger(StringSubstr(tag, 3, -1));

		}

	}



	if (parentTicket == 0) {

		parentTicket = ticket;

	}



	return parentTicket;

}



string e_Reason() {return onTradeEventDetector.EventValueReason();}



string e_ReasonDetail() {return onTradeEventDetector.EventValueDetail();}



double e_attrClosePrice() {return onTradeEventDetector.EventValuePriceClose();}



datetime e_attrCloseTime() {return onTradeEventDetector.EventValueTimeClose();}



string e_attrComment() {return onTradeEventDetector.EventValueComment();}



datetime e_attrExpiration() {return onTradeEventDetector.EventValueTimeExpiration();}



double e_attrLots() {return onTradeEventDetector.EventValueVolume();}



long e_attrMagicNumber() {return onTradeEventDetector.EventValueMagic();}



double e_attrOpenPrice() {return onTradeEventDetector.EventValuePriceOpen();}



datetime e_attrOpenTime() {return onTradeEventDetector.EventValueTimeOpen();}



double e_attrProfit() {return onTradeEventDetector.EventValueProfit();}



double e_attrStopLoss() {return onTradeEventDetector.EventValueStopLoss();}



double e_attrSwap() {return onTradeEventDetector.EventValueSwap();}



string e_attrSymbol() {return onTradeEventDetector.EventValueSymbol();}



double e_attrTakeProfit() {return onTradeEventDetector.EventValueTakeProfit();}



long e_attrTicket() {return onTradeEventDetector.EventValueTicket();}



int e_attrType() {return onTradeEventDetector.EventValueType();}



double fxdCustomIndicator(int handle, int mode=0, int shift=0)

{

	static double buffer[1];



	if (handle < 0)

	{

		Print("Error: Indicator not handled. (handle=",handle," | error code=",GetLastError(),")");

		return 0;

	}



	int tryouts = 0;



	while (true)

	{

		if (BarsCalculated(handle) > 0) break;

		else

		{

			tryouts++;



			if (MQLInfoInteger(MQL_TESTER))

			{

				Sleep(10);

			}

			else

			{

				if (tryouts > 100)

				{

					Print("Error: Custom indicator could not load (handle=",handle," | error code=",GetLastError(),")");



					break;

				}



				Sleep(50);

			}

		}

	}



	int success = CopyBuffer(handle,mode,shift,1,buffer);



	if (success < 0)

	{

		Print("Error: Cannot get value from a custom indicator. (handle=",handle," | error code=",GetLastError(),")");

		return 0;

	}



	//ArraySetAsSeries(buffer,true);



	return buffer[0];

}



double iMA( 

	string             symbol,

	ENUM_TIMEFRAMES    timeframe,

	int                ma_period,

	int                ma_shift,

	ENUM_MA_METHOD     ma_method,

	ENUM_APPLIED_PRICE applied_price,

	int                shift

)

{

	int handle = iMA(symbol, timeframe, ma_period, ma_shift, ma_method, applied_price);

	double val = fxdCustomIndicator(handle, 0, shift);



	return NormalizeDouble(val, 10);

}



double toDigits(double pips, string symbol)

{

	if (symbol == "") symbol = Symbol();



	int digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);



	return NormalizeDouble(pips * PipValue(symbol) * point, digits);

}



double toPips(double digits, string symbol)

{

	if (symbol == "") symbol = Symbol();



   return digits / (PipValue(symbol) * SymbolInfoDouble(symbol, SYMBOL_POINT));

}













class FxdWaiting

{

	private:

		int beginning_id;

		ushort bank  [][2][20]; // 2 banks, 20 possible parallel waiting blocks per chain of blocks

		ushort state [][2];     // second dimention values: 0 - count of the blocks put on hold, 1 - current bank id



	public:

		void Initialize(int count)

		{

			ArrayResize(bank, count);

			ArrayResize(state, count);

		}



		bool Run(int id = 0)

		{

			beginning_id = id;



			int range = ArrayRange(state, 0);

			if (range < id+1) {

				ArrayResize(bank, id+1);

				ArrayResize(state, id+1);



				// set values to 0, otherwise they have random values

				for (int ii = range; ii < id+1; ii++)

				{

				   state[ii][0] = 0;

				   state[ii][1] = 0;

				}

			}



			// are there blocks put on hold?

			int count = state[id][0];

			int bank_id = state[id][1];



			// if no block are put on hold -> escape

			if (count == 0) {return false;}

			else

			{

				state[id][0] = 0; // null the count

				state[id][1] = (bank_id) ? 0 : 1; // switch to the other bank

			}



			//== now we will run the blocks put on hold



			for (int i = 0; i < count; i++)

			{

				int block_to_run = bank[id][bank_id][i];

				_blocks_[block_to_run].run();

			}



			return true;

		}



		void Accumulate(int block_id = 0)

		{

			int count   = ++state[beginning_id][0];

			int bank_id = state[beginning_id][1];



			bank[beginning_id][bank_id][count-1] = (ushort)block_id;

		}

};

FxdWaiting fxdWait;







//+------------------------------------------------------------------+

//| END                                                              |

//| Created with fxDreema EA Builder           https://fxdreema.com/ |

//+------------------------------------------------------------------+



/*<fxdreema:eNrtXety4rgSfpWU9m9mylcwYmurCJA5qYKEA8me2l8uY4tEJ7blI4tJ2Km8y3mWfbIt3YztQC4zzG2j+TFlu1ut7lb3JzVuSAS78FMJbRuCmOQ5ihkmeQn6EbQt+AlDqx9Bl3P4EKwwShPQL2EXgtH4dHA1ueR3HQhKsqYx4jc2BLZ6yCJ6jZh66IL+A4b2gaR5QprzemnOI2kOBLYvxLmHEtcR4rxXilOK7JAnfed/hrzOTnnSe53Xm+vuFGcLcd3Xi/N2inOEuOBQ2nWFuN6htAtA/+FBPF+mJL6VmeLwTOGx7dh8jkDkEqMkFWSfP+tB8IGSdTEliZjAh+Ca36vrD/ragkDMb0Gw2GRLkuoBXD3xQN0sqhs9xIbgZL0pL+gCpXzmEnoQLAm7Af0HoQBXKsI5oop2ieNbfhlAkOAyWqYoAf0ltKRr0D1DVEKBBT89CPNxUs/KHgS4DON1yUimBwbaMdJlQuuSoUzNk5EEpaES40FwTi4KlKPkgiaICp3tLgRFRKMMMUTLMCaEJmXNzA4EBc7zrao+BGUcpdpJOaFZlGoflojLYoTW7OA6sYitxSNHBQXJyWoF+liI9CBIIhZVsz4IFoaZnIV7+pwcFaTEHC3VxGS1EkYrmR4EKVoxLtLucKEuBIwU/D6wuEQPgrsIM21GD4KPEcV8FWq6diEga1asWVkXjMlajLOlrkjdCrEuBHEpuEW82zxSo/iWB1uevItJSqiK/V8GvWHv9FRFYEWxIfhFW7kiOXt3h/D1Das7g6+cjvAQ3TMabTW2HR50fDnflWwjHSbHScB+MyniHChFzlY/aYqcrV6eIl7Xb6aI/0ZTxN2XIh5/5kAwIZWZ22jjBucJjsUyhng6ULFUFxAoodNBgSgmid7RLGXrdFDe4JU+YVlKwnSQIXYjufntxWgcLqR8bsagKFKMkhnFcbXus/nZcBwOJxeL8b5E7EAwq5Tg2s/G87OLUTi8ms/H55fK34uaPrYO1+HFfD4eXp5dnG/dJqMgJlkRUb19/6bsmx/YX/4/w1+cFFNSlnc44fCnBz0TuoeFSPcAENmDYEjypIKZnwEcHQjG08HRydUfi1+X9Ldn0bHXPD/Y/g9ygDg9HQ0Hvc9BxycQ0DMIeBgE/NUg4A+PgN7bRMCeBMDFeDJZPIt+jvWW4M/e/zmCpzzdroR2ljoWBL+TdJ2hWjm1wvcoaVIX+E9BdSGw3ts6uba0OS5vG3m/HapJLgTOe/HJle1q2gzRGOVMkW1LDg00+YSHdo1HnwW4z5K6Yo9wy+bLnK5RKP7fAVo6HH/X9JplT4BBAMEp9848Yphc5Zhpx3h8uCXH+3WmEUplgDsQOJaGtyy7pFGCyhmRy6GBkY/Nsun1WY4ZjtIJYWVLuUAyTNcpw0W6ucgnpCzrtaRjtTlmlKxwE++6kmeQJHyKhhCpR6/F0JDRUHWOSsR2SOg2yPt0sF2ns99YV7PM0UdEyypAo1ReSxmneEn2ynCEt0dRirIlouwZx1Z8eyZ0hEaTaEnW8Q2iaL+4TpNxgkumI9M+do7dY+/YP+5sfb1l3WermHqB/ncSlWjHhLYib5fCh8A9dtQkbkXesRSOIu6buqMz8qooEJ3gDLM6iDgQLBgp+LwaRjy+QeSoTZ7homzgBI/WiigzvdrzRU75vl7oFtvlrAUbFgRJqpkOggkvPB4kxUFnbZr01LzJQeetQ9gTE/OTTHSLZBTtWu4Gw+MFdxrkJ5a8t4NxMWl5yOGLvmX7ZsvO5y0OPO/LFp7PnBx45pctfReC8X31uasLwYfLoTrkjO+LUbSpHx8D8fBfZE3Ltk+5EJyvGarz86Pg+L7YYY6lzWE422mNowsQkqBLxVNtQxY/eGdoUX9nY6nDpSCwKNOfHVsW3IYVJw6jPEnR2ahtAadNI3qLGjDYqw/iVyt+um5vioKFZAXJUc7+QBGtiwha9CnJZdGhGTothlG0qZPb8rn/a2/MakpW

M4iVaO/9DZYFikme7PBdPWMsvcvoVagXWU4FDJrADa8vPz9NVERhdYNaH/ofhG4bRLdG1FFYrVZ9ZBWNLW/KSR+FZIMsnbCTfIsLrlOipvYgYJT7hedMAMEixUURXaNWLTfdDEmWqZNtzZQBpeRuyMuEk/VGpVec0hPh6i+sLG35rv7xyb5eb6qXtV9ccHbEW5Rzcve1q01fvlfVYchfIOkA4J+Ub6+9Go9fXR+iUu0KW49yaeyTdarffIXhWocqU61mmWq/sky1rMCS6FcvUzllJf7tKVbFmzH+ovwL3mbYjilmTTFrillTzJpi1hSzppg1xawpZk0xa4rZn7yY9erFLG+lUwf3OKVzlHy7YvYQLXZ8y0Zp+jaq2UAa+6Jy1vGar12dzg9Sz65W1nerZ/e25wXftYN1reDEgUC0iT5GiT0ZzlXYprKeIU7pCKFihvPbQzfGqu8zfHlnrA3BMCUlks2x3yt3rW+Xu7zNg3fI8Lax5/tp7Wbyurb/dZL3tT0TXidwlt6rk7e2PF+Svt6Pl748CPX1T5K/nsnfz+n6tHQC87an5z9Nbn1pxHUsk8HQ9k13qOkOfRPdodX3QU2D/PPHHa/dIur/k1tEOwYEzZeE3gwIdkyP/At6D94UAHZNW4FpKzBtBaatwLQVmLYC01Zg2gpMW4FpKzBtBaZH/iBtBV3TI/+1euRtr90k75sm+cBUs6aaNdWsqWZNNWuqWVPNmmrWVLOmmjXVrGmSP0g1G5gm+a/XJG+3frfWcf033iQvE6VEjOH8Wlpma2WjmOGPKNwX81xoQcl/UczCXMGt04NgMR0cTQfni8H0arEYHDnvrb/+f5TJmgi1B7JNoeMM3ReIMo0rMUlQmEb59VolsAfB9N8Tv6pCI4bCmKKIQyhfWTfoWF2/63vdoM6SkQSvNvtYsugax2HJIiobk3o+D1qH7+O4xMsUhSle0ohuwqq1uJF4HLE1p8jOfXw85nCGaFhqNMNQtIxyLQqCcxbStYo3V/8lBx1kK0oyvVG+t+RpweFB3DhBqD/Y0B7UlYPawzrqsb39qe/WwEAPfGLkg4SXdYnCj5iydZSGJSPVwTMXA6Q7a1RxnhCZojCxJ0WgDNFrlMebHUI4T4seUpS2t882S5Q0tk/ubfQR5azkgaHjiumI7lXUeBOnKNRdQgrjODnnsBCWBUVREgpIrcjulqwQTRL4wZuhkvHVvyF34bZNSXJIcOH1n2h3kcApN5uSRTkrG706O6DJhyCiKNLAJOMgaJ7ltn8EYF8+1z7m8/sN2HQDtS2oxiIMXdeWkXCjsIgPcvuP+wJlC/XlfDAaL6rURWVMcVE199gQjOqPVDw+MsB5uQFW//FvfdT1d4Id+gf9x7+KfjEbn79W/YeHvwHGh+le

:fxdreema>*/


