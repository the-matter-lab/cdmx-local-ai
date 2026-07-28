#!/usr/bin/env python3
"""Small, headless 2-D Bayesian-optimization animation for the workshop desktop."""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import sys
import time


def dependencies():
    """Import optional plotting dependencies with a useful deployment error."""
    try:
        import numpy as np
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError as exc:
        print(
            "Bayesian demo dependency missing: "
            f"{getattr(exc, 'name', exc)}. Install python3-numpy and "
            "python3-matplotlib.",
            file=sys.stderr,
        )
        return None
    return np, plt


def objective(np, points):
    """A smooth synthetic surface with several tempting local minima."""
    x = points[..., 0]
    y = points[..., 1]
    return (
        0.16 * (x * x + y * y)
        + np.sin(2.2 * x) * np.cos(1.8 * y)
        + 0.25 * np.sin(4.0 * (x + y))
    )


def posterior(np, observed_x, observed_y, candidates, length=0.72, noise=1e-5):
    """RBF Gaussian-process posterior without heavyweight ML dependencies."""
    def kernel(a, b):
        distance = ((a[:, None, :] - b[None, :, :]) ** 2).sum(axis=2)
        return np.exp(-0.5 * distance / (length * length))

    covariance = kernel(observed_x, observed_x)
    covariance.flat[:: len(observed_x) + 1] += noise
    cross = kernel(observed_x, candidates)
    chol = np.linalg.cholesky(covariance)
    centered = observed_y - observed_y.mean()
    alpha = np.linalg.solve(chol.T, np.linalg.solve(chol, centered))
    mean = observed_y.mean() + cross.T @ alpha
    solved = np.linalg.solve(chol, cross)
    variance = np.maximum(1.0 - (solved * solved).sum(axis=0), 1e-9)
    return mean, np.sqrt(variance)


def choose_next(np, observed_x, observed_y, candidates):
    mean, uncertainty = posterior(np, observed_x, observed_y, candidates)
    # Lower confidence bound: exploit low predictions while exploring uncertainty.
    score = mean - 1.35 * uncertainty
    return candidates[int(np.argmin(score))], mean


def render(np, plt, output: Path, observed_x, observed_y, grid, values, iteration):
    output.parent.mkdir(parents=True, exist_ok=True)
    side = int(math.sqrt(len(grid)))
    fig, ax = plt.subplots(figsize=(6.4, 6.65), dpi=100)
    fig.patch.set_facecolor("#111827")
    ax.set_facecolor("#111827")
    contour = ax.contourf(
        grid[:, 0].reshape(side, side),
        grid[:, 1].reshape(side, side),
        values.reshape(side, side),
        levels=22,
        cmap="viridis",
    )
    ax.scatter(
        observed_x[:-1, 0], observed_x[:-1, 1], s=36,
        facecolors="white", edgecolors="#111827", label="samples",
    )
    ax.scatter(
        observed_x[-1, 0], observed_x[-1, 1], s=120, marker="*",
        color="#fb7185", edgecolors="white", label="new sample",
    )
    best = int(np.argmin(observed_y))
    ax.scatter(
        observed_x[best, 0], observed_x[best, 1], s=80, marker="x",
        linewidths=3, color="#facc15", label="best found",
    )
    ax.set_title(f"Bayesian optimization in 2-D  ·  step {iteration}", color="white")
    ax.set_xlabel("x₁", color="white")
    ax.set_ylabel("x₂", color="white")
    ax.tick_params(colors="#d1d5db")
    for spine in ax.spines.values():
        spine.set_color("#6b7280")
    legend = ax.legend(loc="upper right", framealpha=0.85)
    fig.colorbar(contour, ax=ax, shrink=0.78, label="objective (lower is better)")
    fig.tight_layout()
    temporary = output.with_name(f".{output.name}.tmp.png")
    fig.savefig(temporary, facecolor=fig.get_facecolor())
    plt.close(fig)
    os.replace(temporary, output)


def run(output: Path, interval: float, once: bool, seed: int) -> int:
    imported = dependencies()
    if imported is None:
        return 2
    np, plt = imported
    rng = np.random.default_rng(seed)
    axis = np.linspace(-3.0, 3.0, 55)
    xx, yy = np.meshgrid(axis, axis)
    grid = np.column_stack((xx.ravel(), yy.ravel()))
    values = objective(np, grid)

    while True:
        observed_x = rng.uniform(-2.7, 2.7, size=(4, 2))
        observed_y = objective(np, observed_x)
        for iteration in range(4, 25):
            next_point, _ = choose_next(np, observed_x, observed_y, grid)
            observed_x = np.vstack((observed_x, next_point))
            observed_y = np.append(observed_y, objective(np, next_point))
            render(np, plt, output, observed_x, observed_y, grid, values, iteration)
            print(
                f"step={iteration:02d} best={observed_y.min():.4f} "
                f"sample=({next_point[0]:.2f},{next_point[1]:.2f})",
                flush=True,
            )
            if once:
                return 0
            time.sleep(interval)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("latest.png"))
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--once", action="store_true", help="render one frame and exit")
    parser.add_argument("--check", action="store_true", help="only check runtime dependencies")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.check:
        return 0 if dependencies() is not None else 2
    if args.interval <= 0:
        print("--interval must be positive", file=sys.stderr)
        return 64
    return run(args.output, args.interval, args.once, args.seed)


if __name__ == "__main__":
    raise SystemExit(main())
