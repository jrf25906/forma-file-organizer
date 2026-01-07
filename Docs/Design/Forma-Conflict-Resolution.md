# Forma Conflict Resolution System

How Forma decides what to do when multiple rules apply to the same file.

## ⚖️ The Hierarchy of Power

When a file matches multiple rules, the winner is determined by this priority order:

1.  **User-Defined Specific Rules** (Highest)
    *   e.g., "Move `Project_Final.psd` to `~/Client/Finals`"
2.  **User-Defined Pattern Rules**
    *   e.g., "Move `*.psd` to `~/Archive`"
3.  **Smart / System Rules**
    *   e.g., "Move Screenshots to Pictures"
4.  **AI Suggestions** (Lowest)
    *   e.g., "This looks like a receipt"

## 🧩 Tie-Breaking Logic

If two rules have the **same priority** (e.g., two User Pattern rules), we use **Specificity**:

1.  **Path Specificity**: Rules targeting a specific source folder beat global rules.
    *   `~/Downloads/*.jpg` > `*.jpg`
2.  **Name Specificity**: Longer/more complex patterns beat simple ones.
    *   `Screenshot_*.png` > `*.png`
3.  **Recency**: The most recently created/edited rule wins (assumes it reflects current intent).

## 🛑 The "Conflict" State

If the system cannot determine a clear winner (e.g., two identical rules with different destinations), it enters a **Conflict State**:

*   **UI**: The file is flagged with a yellow "Conflict" badge.
*   **Action**: The user *must* manually select the destination.
*   **Resolution**: Forma asks: "Do you want to update the rule to prevent this in the future?"

## 🧪 Examples

**File**: `logo.png` located in `~/Downloads`

*   **Rule A**: "Move `*.png` to `~/Pictures`" (Pattern)
*   **Rule B**: "Move items in `~/Downloads` to `~/Desktop`" (Location)

**Winner**: **Rule A** (Extension match is usually more semantic/intentional than generic location moves, though this is configurable). *Actually, typically specific location rules might override generic extension rules depending on user preference. Let's define specificity strictly:*

**Revised Specificity Score:**
*   +10 for exact name match
*   +5 for extension match
*   +2 for location match

**Scenario**:
*   Rule A (`*.png`): Score 5
*   Rule B (`~/Downloads/*`): Score 2
*   **Result**: Rule A wins.
