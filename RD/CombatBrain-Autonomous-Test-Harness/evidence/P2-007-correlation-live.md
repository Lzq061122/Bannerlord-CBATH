# Correlation evidence - CombatBrain command vs CBATH engine timeline

> legacy CombatBrain temporary adapter output. **Correlation, NOT attribution.**

| field | value |
|---|---|
| CBATH run_id | run-20260924-163216-1 |
| CBATH samples | 373 |
| CBATH mission window | 0.031 .. 374.376 s |
| CombatBrain records | 1380 |
| sampling interval | 1 s |

## Engine-side change counts per formation

| formation | changes | first change times (s) |
|---|---:|---|
| 0/0 | 2 | 109.565, 196.952 |
| 0/1 | 13 | 109.565, 194.942, 196.952, 225.057, 235.092, 243.123 |
| 0/2 | 27 | 109.565, 196.952, 201.975, 217.026, 221.039, 222.046 |
| 0/3 | 28 | 109.565, 196.952, 210, 219.029, 237.097, 238.1 |
| 0/4 | 28 | 202.982, 219.029, 226.057, 228.071, 234.087, 235.092 |
| 1/0 | 6 | 182.895, 219.029, 241.118, 258.186, 298.321, 330.457 |
| 1/1 | 21 | 109.565, 205.987, 218.028, 235.092, 239.106, 249.143 |
| 1/2 | 27 | 109.565, 210, 213.015, 219.029, 223.052, 233.085 |
| 1/3 | 38 | 134.666, 137.688, 138.688, 173.848, 174.852, 181.888 |
| 1/4 | 21 | 109.565, 208.995, 210, 212.01, 214.016, 223.052 |

## Focus: t = 109.5 s

**CombatBrain reported command**

| mission_time | team | f | domain | event | intent | orderType |
|---|---:|---:|---|---|---|---|
| 109.243 | 1 | 0 | Movement | SetterBegin | Hold | 1 |
| 109.243 | 1 | 0 | Movement | SetterCompleted | Hold | 1 |
| 109.243 | 1 | 0 | Movement | ExternalAfterExit | Hold | 1 |

**engine-observed state (CBATH, independent) - team 1 f0**

| CBATH t | delta | active_behavior | movement | arrange | units | position |
|---|---:|---|---|---|---:|---|
| 105.550 | -3.950 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 106.556 | -2.944 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 107.563 | -1.937 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 108.565 | -0.935 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 109.565 | +0.065 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.728,924.418 |
| 110.572 | +1.072 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.134,922.041 |
| 111.576 | +2.076 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 889.439,919.242 |
| 112.581 | +3.081 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 888.703,916.277 |
| 113.587 | +4.087 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 887.976,913.346 |

**NOT PROVEN**: the engine state above is not shown to be caused by the reported command; only the time relationship is established.

## Focus: t = 196.53 s

**CombatBrain reported command**

| mission_time | team | f | domain | event | intent | orderType |
|---|---:|---:|---|---|---|---|
| 196.0302 | 1 | 0 | Movement | SetterBegin | Hold | 1 |
| 196.0302 | 1 | 0 | Movement | SetterCompleted | Hold | 1 |
| 196.0302 | 1 | 0 | Movement | ExternalAfterExit | Hold | 1 |

**engine-observed state (CBATH, independent) - team 1 f0**

| CBATH t | delta | active_behavior | movement | arrange | units | position |
|---|---:|---|---|---|---:|---|
| 192.933 | -3.597 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 193.936 | -2.594 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 194.942 | -1.588 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 195.945 | -0.585 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 196.952 | +0.422 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 197.960 | +1.430 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 198.967 | +2.437 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 199.968 | +3.438 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 200.972 | +4.442 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |

**NOT PROVEN**: the engine state above is not shown to be caused by the reported command; only the time relationship is established.

## Focus: t = 201.98 s

**CombatBrain reported command**

| mission_time | team | f | domain | event | intent | orderType |
|---|---:|---:|---|---|---|---|
| 201.53 | 1 | 0 | Movement | SetterBegin | Hold | 1 |
| 201.53 | 1 | 0 | Movement | SetterCompleted | Hold | 1 |
| 201.53 | 1 | 0 | Movement | ExternalAfterExit | Hold | 1 |

**engine-observed state (CBATH, independent) - team 1 f0**

| CBATH t | delta | active_behavior | movement | arrange | units | position |
|---|---:|---|---|---|---:|---|
| 197.960 | -4.020 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 198.967 | -3.013 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 199.968 | -2.012 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 200.972 | -1.008 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 201.975 | -0.005 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 202.982 | +1.002 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 203.983 | +2.003 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 204.985 | +3.005 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |
| 205.987 | +4.007 | BehaviorCautiousAdvance | Move | ArrangementCloseOrder | 20 | 830.987,684.402 |

**NOT PROVEN**: the engine state above is not shown to be caused by the reported command; only the time relationship is established.

