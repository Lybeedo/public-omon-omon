"""
nexus-optimizer: Genetic Algorithm Parameter Optimizer
=====================================================
Self-improving parameters using DEAP genetic algorithm.
No martingale. Pure evolution.
"""

import random
import json
import numpy as np
from datetime import datetime
from typing import List, Dict, Tuple, Optional
from deap import base, creator, tools, algorithms
from pydantic import BaseModel
from fastapi import FastAPI
import uvicorn

# =============================================================================
# PARAMETER SPACE DEFINITION
# =============================================================================

# All optimizable parameters with ranges
PARAMETER_SPACE = {
    # Trend Filter
    "InpTrendEMA_Fast": (10, 100),
    "InpTrendEMA_Slow": (50, 500),
    
    # Entry
    "InpEntryEMA_Fast": (5, 50),
    "InpEntryEMA_Slow": (10, 100),
    "InpRSIPeriod": (5, 30),
    "InpRSI_Lower": (20, 45),
    "InpRSI_Upper": (55, 80),
    "InpCandleConfirm": (0, 3),
    
    # Risk
    "InpRiskPercent": (0.5, 5.0),
    "InpATR_Mult_SL": (0.5, 5.0),
    "InpATR_Mult_TP": (1.0, 10.0),
    "InpMinRiskReward": (1.0, 5.0),
    
    # SMS
    "InpOBLookback": (5, 30),
    "InpFVGLookback": (1, 10),
    "InpFVGMit": (0.3, 0.9),
    
    # Other
    "InpMaxSpread": (10, 50),
    "InpTrailingStart": (0.5, 5.0),
    "InpTrailingStep": (0.1, 2.0),
}


# =============================================================================
# INDIVIDUAL REPRESENTATION
# =============================================================================

class Individual:
    """
    Single individual in the genetic population.
    """
    
    def __init__(self, params: Dict[str, float]):
        self.params = params
        self.fitness: float = 0.0
        self.metrics: Dict[str, float] = {}
        self.generation: int = 0
    
    def to_list(self) -> List[float]:
        """Convert params dict to flat list."""
        return [self.params[k] for k in sorted(PARAMETER_SPACE.keys())]
    
    @classmethod
    def from_list(cls, values: List[float]) -> "Individual":
        """Create individual from flat list."""
        keys = sorted(PARAMETER_SPACE.keys())
        params = {keys[i]: values[i] for i in range(len(keys))}
        return cls(params)
    
    def clone(self) -> "Individual":
        """Deep copy."""
        return Individual(dict(self.params))
    
    def mutate(self, indpb: float = 0.2, eta: float = 20.0) -> None:
        """
        Polynomial bounded mutation.
        """
        values = self.to_list()
        keys = sorted(PARAMETER_SPACE.keys())
        
        for i, (key, val) in enumerate(zip(keys, values)):
            lo, hi = PARAMETER_SPACE[key]
            
            if random.random() < indpb:
                # Polynomial mutation
                delta = (hi - lo) * 0.5
                x = (val - lo) / (hi - lo) if hi != lo else 0.5
                
                if random.random() < 0.5:
                    x = x - random.uniform(0, 1) ** (1.0 / (eta + 1))
                else:
                    x = x + random.uniform(0, 1) ** (1.0 / (eta + 1))
                
                x = max(0.0, min(1.0, x))
                values[i] = lo + x * (hi - lo)
        
        # Reconstruct params
        self.params = {keys[i]: values[i] for i in range(len(keys))}
    
    def mate(self, other: "Individual") -> Tuple["Individual", "Individual"]:
        """
        Simulated binary crossover (SBX).
        """
        keys = sorted(PARAMETER_SPACE.keys())
        v1 = self.to_list()
        v2 = other.to_list()
        
        for i, key in enumerate(keys):
            lo, hi = PARAMETER_SPACE[key]
            
            # SBX crossover
            if random.random() < 0.5:
                x1, x2 = v1[i], v2[i]
                
                # Polynomial probability
                if abs(x1 - x2) > 1e-10:
                    u = random.random()
                    beta = (u <= 0.5) * (2 * u) ** (1.0 / 21) + (u > 0.5) * (1 / (2 * (1 - u))) ** (1.0 / 21)
                    x1 = 0.5 * ((1 + beta) * x1 + (1 - beta) * x2)
                    x2 = 0.5 * ((1 - beta) * x1 + (1 + beta) * x2)
                
                v1[i] = max(lo, min(hi, x1))
                v2[i] = max(lo, min(hi, x2))
        
        return (
            Individual({keys[i]: v1[i] for i in range(len(keys))}),
            Individual({keys[i]: v2[i] for i in range(len(keys))})
        )


# =============================================================================
# GENETIC ALGORITHM ENGINE
# =============================================================================

class GeneticOptimizer:
    """
    Multi-objective genetic optimizer for VicChelenge EA.
    """
    
    def __init__(self, pop_size: int = 30, ngen: int = 50):
        self.pop_size = pop_size
        self.ngen = ngen
        self.population: List[Individual] = []
        self.hof: List[Individual] = []  # Hall of fame
        self.generation = 0
        self.history: List[Dict] = []
        
        # Stats tracking
        self.stats = {
            "avg_fitness": [],
            "max_fitness": [],
            "min_fitness": [],
        }
    
    def initialize_population(self) -> List[Individual]:
        """Create initial population with random parameters."""
        pop = []
        keys = sorted(PARAMETER_SPACE.keys())
        
        for _ in range(self.pop_size):
            params = {}
            for key in keys:
                lo, hi = PARAMETER_SPACE[key]
                params[key] = random.uniform(lo, hi)
            pop.append(Individual(params))
        
        return pop
    
    def evaluate(self, ind: Individual, metrics: Dict) -> float:
        """
        Multi-objective fitness evaluation.
        
        Metrics expected:
        - win_rate: float (0-1)
        - profit_factor: float (0+)
        - sharpe_ratio: float
        - max_drawdown: float (0-1)
        - total_trades: int
        - net_profit: float
        
        Returns:
            Composite fitness score (higher = better)
        """
        fitness = 0.0
        
        # Filter out weak strategies
        if metrics["total_trades"] < 20:
            fitness = -999  # Not enough trades
            ind.fitness = fitness
            return fitness
        
        if metrics["max_drawdown"] > 0.5:
            fitness -= 50  # Heavy penalty for >50% DD
        
        # === MULTI-OBJECTIVE WEIGHTS ===
        
        # 1. Win Rate (weight: 25%)
        # Target: 40-60% win rate is optimal
        win_rate = metrics["win_rate"]
        if win_rate > 0.35:
            wr_score = (win_rate - 0.35) / 0.35 * 25  # 35%+ = full score
        else:
            wr_score = max(0, (win_rate - 0.25) / 0.10 * 10)  # Below 25% = penalty
        fitness += wr_score
        
        # 2. Profit Factor (weight: 25%)
        pf = metrics.get("profit_factor", 1.0)
        pf_score = min(25, pf * 10)  # PF 2.5 = max score
        fitness += pf_score
        
        # 3. Sharpe Ratio (weight: 20%)
        sharpe = metrics.get("sharpe_ratio", 0)
        sharpe_score = max(0, sharpe * 15)  # Sharpe 1.0 = decent
        fitness += sharpe_score
        
        # 4. Drawdown Penalty (weight: 15%)
        dd = metrics["max_drawdown"]
        dd_score = (1 - dd) * 15  # 0% DD = full score, 100% DD = 0
        fitness += dd_score
        
        # 5. Trade Frequency (weight: 5%)
        trades = metrics["total_trades"]
        tf_score = min(5, trades / 50)  # 50 trades in backtest period = full score
        fitness += tf_score
        
        # 6. Consistency Bonus (weight: 10%)
        # Reward strategies with consistent returns
        if "daily_returns" in metrics and len(metrics["daily_returns"]) > 5:
            returns = metrics["daily_returns"]
            std = np.std(returns)
            mean = np.mean(returns)
            cv = std / mean if mean > 0 else 999  # Coefficient of variation
            cons_score = max(0, 10 - cv * 50)  # Low CV = consistent = high score
            fitness += cons_score
        
        ind.fitness = fitness
        ind.metrics = metrics
        return fitness
    
    def select_tournament(self, individuals: List[Individual], k: int = 3) -> Individual:
        """Tournament selection."""
        selected = random.sample(individuals, min(k, len(individuals)))
        return max(selected, key=lambda x: x.fitness)
    
    def evolve(self, initial_metrics: List[Dict] = None) -> List[Individual]:
        """
        Run genetic algorithm evolution.
        """
        print(f"=== nexus-optimizer: Starting evolution ===")
        print(f"  Population: {self.pop_size}")
        print(f"  Generations: {self.ngen}")
        print(f"  Parameters: {len(PARAMETER_SPACE)}")
        
        # Initialize population
        self.population = self.initialize_population()
        self.generation = 0
        
        # Evaluate initial population
        if initial_metrics:
            for i, ind in enumerate(self.population):
                m = initial_metrics[i] if i < len(initial_metrics) else {
                    "win_rate": 0.35, "profit_factor": 1.5, "sharpe_ratio": 0.5,
                    "max_drawdown": 0.2, "total_trades": 50, "daily_returns": []
                }
                self.evaluate(ind, m)
        
        # Hall of fame
        self.hof = sorted(self.population, key=lambda x: x.fitness, reverse=True)[:10]
        
        # Evolution loop
        for gen in range(self.ngen):
            self.generation = gen
            
            # Create offspring
            offspring = []
            for _ in range(self.pop_size):
                if random.random() < 0.5:
                    # Crossover
                    p1 = self.select_tournament(self.population)
                    p2 = self.select_tournament(self.population)
                    c1, c2 = p1.mate(p2)
                    offspring.extend([c1, c2])
                else:
                    # Mutation
                    ind = self.select_tournament(self.population).clone()
                    ind.mutate()
                    offspring.append(ind)
            
            # Limit offspring
            offspring = offspring[:self.pop_size]
            
            # Evaluate offspring (in production, this would run backtests)
            # For now, assign random fitness (placeholder)
            for ind in offspring:
                # Simulated evaluation
                metrics = {
                    "win_rate": random.uniform(0.35, 0.55),
                    "profit_factor": random.uniform(1.2, 3.0),
                    "sharpe_ratio": random.uniform(0.3, 1.5),
                    "max_drawdown": random.uniform(0.05, 0.3),
                    "total_trades": random.randint(30, 200),
                    "daily_returns": [random.uniform(-0.02, 0.03) for _ in range(30)]
                }
                self.evaluate(ind, metrics)
            
            # Select next generation
            self.population = sorted(offspring + self.population, key=lambda x: x.fitness, reverse=True)[:self.pop_size]
            
            # Update hall of fame
            new_hof = sorted(self.population, key=lambda x: x.fitness, reverse=True)[:10]
            self.hof.extend(new_hof)
            self.hof = sorted(self.hof, key=lambda x: x.fitness, reverse=True)[:10]
            
            # Stats
            fitnesses = [x.fitness for x in self.population]
            self.stats["avg_fitness"].append(np.mean(fitnesses))
            self.stats["max_fitness"].append(np.max(fitnesses))
            self.stats["min_fitness"].append(np.min(fitnesses))
            
            if gen % 10 == 0 or gen == self.ngen - 1:
                print(f"  Gen {gen:3d}: Best={max(fitnesses):.2f} | Avg={np.mean(fitnesses):.2f}")
        
        print("=== Evolution complete ===")
        print(f"  Hall of Fame: {len(self.hof)} individuals")
        
        return self.hof
    
    def get_best_params(self) -> Dict[str, float]:
        """Get best parameters from hall of fame."""
        if not self.hof:
            return {k: (PARAMETER_SPACE[k][0] + PARAMETER_SPACE[k][1]) / 2 
                    for k in PARAMETER_SPACE}
        
        best = self.hof[0]
        return dict(best.params)
    
    def get_top_params(self, n: int = 5) -> List[Dict]:
        """Get top N parameter sets."""
        results = []
        for i, ind in enumerate(self.hof[:n]):
            results.append({
                "rank": i + 1,
                "fitness": ind.fitness,
                "params": dict(ind.params),
                "metrics": ind.metrics
            })
        return results


# =============================================================================
# FASTAPI APP
# =============================================================================

app = FastAPI(title="nexus-optimizer", version="1.0")
optimizer = GeneticOptimizer()


@app.get("/")
async def root():
    return {
        "service": "nexus-optimizer",
        "version": "1.0",
        "status": "running",
        "param_space_size": len(PARAMETER_SPACE)
    }


@app.get("/health")
async def health():
    return {"status": "healthy", "service": "nexus-optimizer"}


@app.get("/api/v1/optimizer/params")
async def get_param_space():
    """Get parameter space definition."""
    return {"parameter_space": PARAMETER_SPACE}


@app.post("/api/v1/optimizer/evolve")
async def run_evolution(
    pop_size: int = 30,
    ngen: int = 50,
    initial_metrics: list = []
):
    """
    Run genetic algorithm evolution.
    
    Args:
        pop_size: Population size (default 30)
        ngen: Number of generations (default 50)
        initial_metrics: List of metrics for initial population
    """
    global optimizer
    optimizer = GeneticOptimizer(pop_size=pop_size, ngen=ngen)
    hof = optimizer.evolve(initial_metrics if initial_metrics else None)
    
    return {
        "generations": ngen,
        "population_size": pop_size,
        "best_params": optimizer.get_best_params(),
        "top_params": optimizer.get_top_params(5),
        "stats": optimizer.stats
    }


@app.get("/api/v1/optimizer/best")
async def get_best():
    """Get current best parameters."""
    return {"best_params": optimizer.get_best_params()}


@app.get("/api/v1/optimizer/top")
async def get_top(n: int = 5):
    """Get top N parameter sets."""
    return {"top_params": optimizer.get_top_params(n)}


@app.get("/api/v1/optimizer/history")
async def get_history():
    """Get evolution history."""
    return {"history": optimizer.history}


# =============================================================================
# STANDALONE RUN
# =============================================================================

if __name__ == "__main__":
    print("=== nexus-optimizer starting on port 8003 ===")
    uvicorn.run(app, host="0.0.0.0", port=8003)