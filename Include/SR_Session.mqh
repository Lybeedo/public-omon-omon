//+------------------------------------------------------------------+
//|                                                SR_Session.mqh   |
//|                          Cuancux Algo Traders • Paulus Is        |
//+------------------------------------------------------------------+
#ifndef SR_SESSION_MQH
#define SR_SESSION_MQH

//+------------------------------------------------------------------+
//|  NY Session Filter                                               |
//|  Only allow trading between NY open (8 AM) and NY close (5 PM)   |
//|  Times are in broker server time (MT5 handles conversion)        |
//+------------------------------------------------------------------+
class CSR_Session
  {
private:
   bool     m_enabled;
   int      m_startHour;
   int      m_startMin;
   int      m_endHour;
   int      m_endMin;

public:
   CSR_Session(void) : m_enabled(true), m_startHour(8), m_startMin(0),
                        m_endHour(17), m_endMin(0) {}

   void Configure(bool enabled, int startH, int startM, int endH, int endM)
     {
      m_enabled   = enabled;
      m_startHour = startH; m_startMin = startM;
      m_endHour   = endH;   m_endMin   = endM;
     }

   bool IsSessionOpen(void) const
     {
      if(!m_enabled) return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      int nowMins = dt.hour * 60 + dt.min;
      int startMins = m_startHour * 60 + m_startMin;
      int endMins   = m_endHour * 60 + m_endMin;

      // Handle overnight (e.g. 22:00 to 06:00)
      if(startMins > endMins)
        {
         // session spans midnight
         return (nowMins >= startMins || nowMins <= endMins);
        }

      return (nowMins >= startMins && nowMins <= endMins);
     }

   string SessionInfo(void) const
     {
      if(!m_enabled) return "Session filter DISABLED (all hours allowed)";
      return StringFormat("NY Session: %02d:%02d - %02d:%02d  currently=%s",
                          m_startHour, m_startMin, m_endHour, m_endMin,
                          IsSessionOpen() ? "OPEN" : "CLOSED");
     }
  };

#endif
//+------------------------------------------------------------------+