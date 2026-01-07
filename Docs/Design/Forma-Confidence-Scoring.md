# Forma Confidence Scoring Algorithm

To ensure users trust Forma, every suggestion comes with a "Confidence Score" (0.0 to 1.0). This score determines how the suggestion is presented in the UI.

## 🎯 Scoring Logic

The final score is calculated as:
`Score = Base Score + Boosters - Penalties` (Clamped between 0.0 and 1.0)

### 1. Base Score (By Source)
| Source | Score | Description |
| :--- | :--- | :--- |
| **Exact Rule Match** | `1.0` | User explicitly created this rule (e.g., "Move *.png to Screenshots"). |
| **Smart Pattern** | `0.8` | System detected a strong pattern (e.g., "All .dmg files go to Trash"). |
| **Heuristic Guess** | `0.6` | Based on file type conventions (e.g., "Images usually go to Pictures"). |
| **LLM Suggestion** | `0.5` | AI-generated suggestion based on filename/content context. |

### 2. Boosters (Contextual Signals)
| Signal | Value | Why |
| :--- | :--- | :--- |
| **History Match** | `+0.1` (per accept) | User has accepted similar moves before (Max +0.3). |
| **Folder Affinity** | `+0.1` | Destination folder name matches file type (e.g., "vacation.jpg" -> "Vacation Photos"). |
| **Staleness** | `+0.05` | File hasn't been opened in > 30 days (easier to archive). |
| **Cluster Size** | `+0.05` | Part of a group of 5+ similar files being moved together. |

### 3. Penalties (Risk Factors)
| Risk | Value | Why |
| :--- | :--- | :--- |
| **Destructive Action** | `-0.2` | Moving to Trash is high risk. |
| **Ambiguity** | `-0.2` | Multiple rules matched this file. |
| **System Folder** | `-0.5` | Source or destination involves a system path (e.g., Library). |
| **New Rule** | `-0.1` | Rule was created < 24 hours ago. |

## 🚦 UI Thresholds

How the score affects the user interface:

*   **High Confidence (0.9 - 1.0)**
    *   **UI**: "Auto-Organize" candidate (if enabled).
    *   **Badge**: Green checkmark.
    *   **Action**: One-click "Do it all".

*   **Medium Confidence (0.6 - 0.8)**
    *   **UI**: Standard suggestion list.
    *   **Badge**: Yellow "Review".
    *   **Action**: Requires user to glance and click "Accept".

*   **Low Confidence (< 0.6)**
    *   **UI**: "Unsure" section or hidden by default.
    *   **Badge**: Red question mark.
    *   **Action**: Explicitly asks "Is this right?".

## 🧮 Example Calculation

**Scenario**: Moving `Project_Final_v2.psd` to `~/Archive/Projects`.
*   **Rule**: "Move *.psd to Archive" (Base: `1.0`)
*   **History**: User accepted this twice before (`+0.2`)
*   **Staleness**: File is 2 days old (No boost)
*   **Risk**: None
*   **Calculation**: `1.0 + 0.2 = 1.2` -> **Clamped to 1.0**

**Scenario**: Moving `unknown_file.xyz` to Trash.
*   **Rule**: AI suggested based on "unknown" name (Base: `0.5`)
*   **History**: None
*   **Risk**: Destructive (`-0.2`)
*   **Calculation**: `0.5 - 0.2 = 0.3` -> **Low Confidence**
