---
story_id: story-999-9
capabilities: [CAP-1]
---
### Story 1.1: Venue Recorded On An Executed Rebalance Leg

As a gated-pool operator,
I want the venue recorded on the leg itself,
So that I can tell which path actually ran.

**Acceptance Criteria:**

**Given** a rebalance leg the keeper has executed
**When** I read that leg's execution record
**Then** the record definitively names the venue that executed the leg
**And** an exhaustive search of every call site confirms no other writer
