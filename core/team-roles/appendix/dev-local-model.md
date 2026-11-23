- The lead may route to `dev` stories that meet ALL of the following criteria
  when `aiDlcRoles.dev` names a local model:
  - The story has a precise implementation checklist with specific functions,
    file paths, input/output contracts, and test cases defined in the ACs.
  - No architectural judgment or cross-file reasoning beyond the files listed
    in the story.
  - No ambiguous or open-ended acceptance criteria.
  - The implementation does not require reading large amounts of existing code
    to understand context (the story spec provides all necessary context).
  - The story does not involve complex multi-step test-fix-retest cycles.
  Local model assignments are a cost optimization for high-volume, fully
  prescribed work. If you are running on a local model and encounter a task
  that exceeds these boundaries, message the lead (`SendMessage` `to: "main"`) immediately. The lead will
  re-route the story to a role whose configured model can carry it rather than
  having you struggle through it.
