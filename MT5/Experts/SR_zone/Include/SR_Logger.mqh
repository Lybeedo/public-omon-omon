//+------------------------------------------------------------------+
//|                                                SR_Logger.mqh    |
//|                          Cuancux Algo Traders • Paulus Is        |
//+------------------------------------------------------------------+
#ifndef SR_LOGGER_MQH
#define SR_LOGGER_MQH

//+------------------------------------------------------------------+
//|  ChartComment log helper                                          |
//+------------------------------------------------------------------+
class CSR_Logger
  {
private:
   string            m_lines[30];
   int               m_count;
   int               m_logLevel;

public:
                     CSR_Logger(void);
                    ~CSR_Logger(void);

   void              Configure(int logLevel, int maxLines);

   void              Clear(void);
   void              Add(string line);
   void              AddLine(string label, string value);
   void              AddLine(string label, double value, int decimals=5);
   void              AddLine(string label, int value);
   void              AddLine(string label, bool value);
   void              AddBlank(void);

   string            BuildComment(void) const;
   void              Render(void);

   void              Log(string msg);
  };

//+------------------------------------------------------------------+
CSR_Logger::CSR_Logger(void) : m_count(0), m_logLevel(1)
  {
   for(int i = 0; i < 30; i++) m_lines[i] = "";
  }

//+------------------------------------------------------------------+
CSR_Logger::~CSR_Logger(void) {}

//+------------------------------------------------------------------+
void CSR_Logger::Configure(int logLevel, int maxLines)
  {
   m_logLevel = logLevel;
   Clear();
   (void)maxLines; // kept for API compat
  }

//+------------------------------------------------------------------+
void CSR_Logger::Clear(void)
  {
   m_count = 0;
   for(int i = 0; i < 30; i++) m_lines[i] = "";
  }

//+------------------------------------------------------------------+
void CSR_Logger::Add(string line)
  {
   for(int i = 0; i < 29; i++)
      m_lines[i] = m_lines[i+1];
   m_lines[29] = line;
   if(m_count < 30) m_count++;
  }

//+------------------------------------------------------------------+
void CSR_Logger::AddLine(string label, string value)
  {
   Add(label + ": " + value);
  }

//+------------------------------------------------------------------+
void CSR_Logger::AddLine(string label, double value, int decimals)
  {
   Add(StringFormat("%s: %.*f", label, decimals, value));
  }

//+------------------------------------------------------------------+
void CSR_Logger::AddLine(string label, int value)
  {
   Add(StringFormat("%s: %d", label, value));
  }

//+------------------------------------------------------------------+
void CSR_Logger::AddLine(string label, bool value)
  {
   Add(label + ": " + (value ? "YES" : "NO"));
  }

//+------------------------------------------------------------------+
void CSR_Logger::AddBlank(void)
  {
   Add(" ");
  }

//+------------------------------------------------------------------+
string CSR_Logger::BuildComment(void) const
  {
   string out = "=== XAUUSD S/R EA ===\n";
   for(int i = 0; i < 30; i++)
     {
      if(m_lines[i] == "") continue;
      out += m_lines[i] + "\n";
     }
   return out;
  }

//+------------------------------------------------------------------+
void CSR_Logger::Render(void)
  {
   Comment(BuildComment());
  }

//+------------------------------------------------------------------+
void CSR_Logger::Log(string msg)
  {
   if(m_logLevel < 1) return;
   Print("[", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "] ", msg);
  }

#endif
//+------------------------------------------------------------------+