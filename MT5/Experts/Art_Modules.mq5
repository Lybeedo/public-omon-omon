//+------------------------------------------------------------------+
//|                                           Art_Modules_MarketStats.mq5 |
//|                                    Copyright 2024, Trader Nakal™ Team   |
//+------------------------------------------------------------------+
#property copyright "Trader Nakal™ - Omon Agent"
#property version   "1.00"
#property strict

#include <Arrays\ArrayObj.mqh>

//+=================================================================+
//| MARKET STATISTIC CLASS                                          |
//| Mengubah array double -> tabel frekuensi pakai metode Sturges     |
//+=================================================================+
class MarketStatistic
{
private:
   double        m_data[];       // Data mentah
   int           m_n;            // Jumlah data point
   double        m_min;          // Nilai minimum
   double        m_max;          // Nilai maksimum
   int           m_k;            // Jumlah bins (Sturges)
   double        m_range;        // Range (max - min)
   double        m_binWidth;     // Lebar setiap bin
   double        m_lowerEdge[];  // Tepi bawah tiap bin
   int           m_frequency[];  // Frekuensi tiap bin
   double        m_percentage[]; // Persentase tiap bin
   double        m_cumPerc[];    // Cumulative persentase
   
   //--- Hitung jumlah bins pakai Sturges' Formula
   int SturgesFormula(int n)
   {
      if(n <= 0) return(1);
      if(n <= 1) return(1);
      return((int)MathRound(1 + 3.322 * MathLog(n) / MathLog(10)));
   }
   
   //--- Assign nilai ke bin yang sesuai
   int GetBinIndex(double value, double minVal, double width, int bins)
   {
      int idx = (int)((value - minVal) / width);
      if(idx >= bins) idx = bins - 1;
      if(idx < 0) idx = 0;
      return(idx);
   }
   
public:
              MarketStatistic();
              ~MarketStatistic();
   
   void            SetData(const double &data[], int size);
   string          CalculateTable(string title = "MARKET STATISTICS");
   
   int             Count() const { return(m_n); }
   double          Min()   const { return(m_min); }
   double          Max()   const { return(m_max); }
   double          Mean()  const;
   double          StdDev()const;
   int             Bins()  const { return(m_k); }
   double          BinWidth()const { return(m_binWidth); }
};

//+=================================================================+
//| CONSTRUCTOR                                                      |
//+=================================================================+
MarketStatistic::MarketStatistic()
{
   ArrayInitialize(m_frequency, 0);
   m_n       = 0;
   m_min     = 0.0;
   m_max     = 0.0;
   m_range   = 0.0;
   m_binWidth = 0.0;
   m_k       = 0;
}

//+=================================================================+
//| DESTRUCTOR                                                       |
//+=================================================================+
MarketStatistic::~MarketStatistic()
{
   ArrayFree(m_data);
   ArrayFree(m_lowerEdge);
   ArrayFree(m_frequency);
   ArrayFree(m_percentage);
   ArrayFree(m_cumPerc);
}

//+=================================================================+
//| SET DATA DARI ARRAY DOUBLE                                       |
//+=================================================================+
void MarketStatistic::SetData(const double &data[], int size)
{
   // Copy data
   m_n = MathMax(size, 0);
   if(m_n == 0) return;
   
   ArrayResize(m_data, m_n);
   for(int i = 0; i < m_n; i++)
      m_data[i] = data[i];
      
   // Cari min dan max
   m_min = m_data[0];
   m_max = m_data[0];
   for(int i = 1; i < m_n; i++)
   {
      if(m_data[i] < m_min) m_min = m_data[i];
      if(m_data[i] > m_max) m_max = m_data[i];
   }
   
   // Hitung range & Sturges' bins
   m_range = m_max - m_min;
   m_k     = SturgesFormula(m_n);
   m_binWidth = (m_range > 0.0) ? (m_range / m_k) : 1.0;
      
   // Reset counters
   ArrayFree(m_frequency);
   ArrayFree(m_percentage);
   ArrayFree(m_cumPerc);
   ArrayFree(m_lowerEdge);
   ArrayResize(m_frequency, m_k, 0);
   ArrayResize(m_percentage, m_k, 0.0);
   ArrayResize(m_cumPerc, m_k, 0.0);
   ArrayResize(m_lowerEdge, m_k, 0.0);
   
   // Hitung tepi bawah dan frekuensi tiap bin
   double cumPercent = 0.0;
   for(int i = 0; i < m_k; i++)
   {
      m_lowerEdge[i] = m_min + (i * m_binWidth);
      
      // Hitung frekuensi untuk bin ini
      for(int j = 0; j < m_n; j++)
      {
         if(i == (m_k - 1))
         {
            // Bin terakhir: termasuk max value
            if(m_data[j] >= m_lowerEdge[i] && m_data[j] <= m_max)
               m_frequency[i]++;
         }
         else
         {
            // Bin lainnya: [lower, upper)
            if(m_data[j] >= m_lowerEdge[i] && m_data[j] < m_lowerEdge[i + 1])
               m_frequency[i]++;
         }
      }
      
      // Kalkulasi persentase & cumulative
      m_percentage[i] = (m_n > 0) ? ((double)m_frequency[i] / m_n) * 100.0 : 0.0;
      cumPercent += m_percentage[i];
      m_cumPerc[i] = cumPercent;
   }
}

//+=================================================================+
//| HITUNG RATA-RATA                                                 |
//+=================================================================+
double MarketStatistic::Mean() const
{
   if(m_n == 0) return(0.0);
   double sum = 0.0;
   for(int i = 0; i < m_n; i++)
      sum += m_data[i];
   return(sum / m_n);
}

//+=================================================================+
//| HITUNG STANDAR DEVIALSI                                          |
//+=================================================================+
double MarketStatistic::StdDev() const
{
   if(m_n <= 1) return(0.0);
   double mean = Mean();
   double sqSum = 0.0;
   for(int i = 0; i < m_n; i++)
   {
      double diff = m_data[i] - mean;
      sqSum += diff * diff;
   }
   return(MathSqrt(sqSum / (m_n - 1)));
}

//+=================================================================+
//| GENERASI TABEL FREKUENSI (STRING OUTPUT)                         |
//+=================================================================+
string MarketStatistic::CalculateTable(string title = "MARKET STATISTICS")
{
   ResetLastError();
   
   if(m_n == 0 || m_k == 0)
      return("ERROR: No data available.\n");
      
   string result = "";
   
   // Header section
   result += StringFormat("%s\n", title);
   result += "=======================================================\n";
   result += StringFormat("  N    : %d data points\n", m_n);
   result += StringFormat("  Min  : %.5f\n", m_min);
   result += StringFormat("  Max  : %.5f\n", m_max);
   result += StringFormat("  Mean : %.5f\n", Mean());
   result += StringFormat("  StdDev: %.5f\n", StdDev());
   result += StringFormat("  Range: %.5f\n", m_range);
   result += StringFormat("  K    : %d bins (Sturges' Formula)\n", m_k);
   result += StringFormat("  BinWidth: %.5f\n", m_binWidth);
   result += "=======================================================\n";
   result += "\n";
   
   // Table header
   result += StringFormat("+---------------+----------+----------+----------+\n");
   result += StringFormat("| Interval      | Freq     | Perc (%) | Cum Perc |\n");
   result += StringFormat("+---------------+----------+----------+----------+\n");
   
   // Table rows
   for(int i = 0; i < m_k; i++)
   {
      string intervalStr;
      
      if(i == (m_k - 1))
      {
         intervalStr = StringFormat(" %9.4f - %9.4f ", m_lowerEdge[i], m_max);
         result += StringFormat("|%15s%8d |%7.2f%% |%7.2f%% |\n", 
                                intervalStr,
                                m_frequency[i],
                                m_percentage[i],
                                m_cumPerc[i]);
      }
      else
      {
         intervalStr = StringFormat(" %9.4f - %9.4f ", m_lowerEdge[i], m_lowerEdge[i + 1]);
         result += StringFormat("|%15s%8d |%7.2f%% |%7.2f%% |\n",
                                intervalStr,
                                m_frequency[i],
                                m_percentage[i],
                                m_cumPerc[i]);
      }
   }
   
   // Table footer
   result += StringFormat("+---------------+----------+----------+----------+\n");
   result += StringFormat("| %16d |%7.2f%% |%7.2f%% |\n",
                          m_n, 100.0, m_cumPerc[m_k - 1]);
   result += "+---------------+----------+----------+----------+\n";
   result += "\n";
   
   Print(result);
   return(result);
}
//+------------------------------------------------------------------+
