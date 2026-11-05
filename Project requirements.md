# Project 4: Someone Else's Mechanics, Your Story / Found

- Due: Wed Nov 4, 2026 11:59pm
- 80 Points Possible
- Attempt 1
- Submitted on Oct 26, 2026 5:01pm
- NEXT UP: Review Feedback
- Attempt 1 Score:
- N/A

- Unlimited Attempts Allowed

## Due dates

- Kickoff: Wednesday, October 21. Your team is listed in the Project 4 Kickoff classwork.
- Mechanics, for the team you write for: Friday, October 23, by 4:00 pm.
- Swap Day: Friday, October 23, in class. You receive the mechanics your team will build.
- Find the Story homework: Sunday, October 25, by 11:59 pm.
- Story, with your clarity rating: Monday, October 26, by 11:59 pm.
- Playtest 1: Wednesday, October 28, start of class. Bring a live link and headphones.
- No class: Friday, October 30.
- Final build, exported and pushed: Wednesday, November 4, by 4:00 pm. The final playtest runs on this build in class.
- Video, post-mortem, and contribution split: Wednesday, November 4, by 11:59 pm.

In Canvas: Project 4 Checkpoint: Mechanics (10 points), Project 4 Checkpoint: Story (10 points), and the main submission (80 points), plus a confidential contribution split worth no points on its own. If you do not submit the split by 11:59 pm November 4, 5 points come off your main assignment.

## The Constraint

One mechanic per member. Someone else's mechanics, your story. Found.

Teams of three or four. Godot 4. Exported to the web and hosted out of your repo. Your team builds mechanics another team wrote, and tells a story the player finds in the world.

### What This Constraint Is For

Many games you will work on start from a design someone else wrote. You build what the document says, and where it is unclear you make a call and write it down. The story then has to make sense of mechanics you did not choose.

### One mechanic per member

A mechanic is something the player does, the rules for it, and the numbers. Basic movement does not count as one.

Your team writes one mechanic per member of the team you write for. Each mechanic has to change how at least one other mechanic in the set plays. I check by turning one mechanic off. If another mechanic now plays differently in a way a player would notice, the first one changes it.

Your team builds the set it receives, and each member owns one of those mechanics. You may not add a mechanic or cut one. You can add levels, objects and content, but no new player actions or rules.

If a member leaves your team, or I confirm a teammate has stopped showing up, their mechanic comes out of the count, along with anything that only connected to it. If you keep building it anyway, it is graded like the others. Email me the day you notice.

### Someone else's mechanics

Do not contact the team that wrote your mechanics, or the team you wrote for, about this project until the final playtest is over. I pass the mechanics between teams.

Where the mechanics are unclear, your team makes a call and writes it down in the clarity rating. Where I agree the checkpoint left it open, a mechanic built to a guess you wrote down there counts as built as written. The guess has to be specific enough to check against the build. "We tune the numbers ourselves" is not a guess.

If the set you receive is missing a mechanic, arrives late, or cannot be built, email me by Monday, October 26. I tell you what to build in its place, and that counts as built as written.

Mechanics checkpoint. One PDF per team, uploaded by every member by 4:00 pm Friday, October 23. Use "the player" and "the object", never "the knight" and "the sword". No setting, characters, story or art. For each mechanic:

- Its name, and the input that does it.
- The rules and the numbers.
- Which other mechanic in the set it changes, and how.
- Then say how the player wins and how the player loses.

## Your story

Story checkpoint. One PDF per team, uploaded by every member by 11:59 pm Monday, October 26. Put the author's name on each section. Six sections:

- Premise in one sentence.
- Beats. The story's parts, using one structure from the Find the Story homework, and where in the game each one happens.
- A reason for every mechanic. For each one, the story's reason the player does it.
- Found moments. At least three things the player finds in the world that tell the story: an object, a place, a sound, or something left behind. Say where each one is.
- Clarity rating. For each mechanic you received, mark it "clear" or "had to guess". For each guess, write the question you could not ask and the answer your team is building to.
- Text. Every piece of text and speech you plan to put in the game, with a word count.

Your game will change. Your team can revise sections 1 to 4 and 6 once: one member emails me the new version before 4:00 pm November 4. The final playtest uses the latest version. The checkpoint grade is for the October 26 version. The clarity rating cannot be revised.

## Found

The whole game shows at most 150 words of text. Words on signs and objects in the world count, and so do spoken words, labels on the screen, and win or lose screens. The game's name, menu buttons, and a controls screen listing key bindings do not count. Over 150 words caps game execution at 10 of 20.

## The Playtests

Each playtest has its own Canvas discussion. At the start of class, one member of your team posts your live link there as a new thread. I pair the teams, and on November 4 you play different games than on October 28. Teams play at the same time, on their own laptops, with headphones.

Each playtester plays your game cold, meaning they have never played it. On October 28 they play for up to 15 minutes. On November 4 every member plays two games, up to 12 minutes each. Playtesters can restart as often as they like, so keep a full run to about 10 minutes. Do not help them or answer questions. Then each playtester replies on your thread with a playtest report:

- Retell it. The story in two sentences.
- Found it. One thing in the world, without reading, and what it told them about the story.
- The miss. One thing they did in the game that the story never gave them a reason for, or one moment they did not understand.

On November 4, one of the two teams that plays your game is the team that wrote your mechanics. They file one item instead:

- Built as written. For each mechanic in their checkpoint: built as written, changed, or missing. If changed, what changed.

Posting your reports on the other team's thread by the end of class is a classwork grade at both playtests. Only reports posted by the end of class count. A retelling or "found it" answer that repeats an earlier one on the thread counts once. On November 4, post each report right after each game. If fewer than two story reports arrive for a game, I play it and post reports until there are two. Mine count for the story rows only if no student story reports arrive. I decide whether a retelling matches your story and whether a mechanic was built as written, and I check every author report against the checkpoint and your clarity rating.

## Godot and Your Team

One member creates a public repo with the Godot project inside it, and the others are added as collaborators. Check git config user.email matches your GitHub account. Working on a teammate's laptop? End the commit message with Co-authored-by: Your Name &lt;your email&gt;. Each owner stays in their own scenes and scripts.

Set the renderer to Compatibility before you build anything. The web export cannot run Forward+.

Web export: export index.html into a docs/ folder containing an empty .gdignore file, and serve Pages from main, /docs. Uncheck Thread Support under Variant in the Web preset. Your live link plays your last export, not your latest code, so export again after every change. Test it in a private window on a machine that is not yours.

## Deliverables

- Mechanics checkpoint, October 23. See above.
- Story checkpoint, October 26. See above.
- Playable build, October 28. Bring your live link. Two working mechanics and one found moment are enough to playtest.
- Game. Exported, committed, and pushed by 4:00 pm November 4. Push by 3:45 pm and open the live link in a private window before class. Game execution and version control are graded on your repo and live link as of 4:00 pm. Commits after that count for nothing.
- Video walkthrough. Individual, in your own voice. Aim for 5 to 8 minutes, with game or code on screen throughout. Under 4 or over 10 is minus 5. A step with nothing on screen scores half. Steps b, c, d and e are about your own mechanic, so a teammate's video cannot earn them for you. Cover all six steps below, in any order.
- Post-mortem. Individual. One PDF uploaded to the main assignment, with your repo link, live link, and video link on its first page.
- Contribution split. Individual and confidential. Its own Canvas item.

### Video steps:

- a. Play the team's game, about a minute.
- b. Your mechanic. Open the real files: where its state lives, which node holds it, what moves it. Then, in one continuous take, pick a value that changes how your mechanic plays (not a color or label) in a line your own commit put there, say what you expect, change it, run, show what happened, and change it back.
- c. The mechanic yours changes. What the checkpoint said, how your team built it, and where you had to guess.
- d. The playtest record, the heaviest step. One thing the October 28 reports said about your mechanic or the part of the story it carries. What you changed, and what the November 4 reports showed.
- e. The story's reason for your mechanic, and one found moment that gives it.
- f. Your most and least confident code, with a reason and a fix for each.

## Post-Mortem Requirements

- What went well and what went wrong, specific and honest
- What you personally built, and what you would build differently now
- Where your team had to guess at the mechanics, and whether the guess held up
- Your beats against what playtesters retold
- Which found moments no playtester named, and why
- As an author: what the other team did with your mechanics, and what you would write differently
- Where AI output diverged from your story or the mechanics, and whether you corrected or accepted it
- What changed between October 28 and November 4, and whether it worked

## Contribution Split

Split 100 points across your team, yourself included, by how much each person contributed. Code, art, audio, design, the checkpoints, and testing all count. I never show your split to your teammates. It changes a grade in one case only: if at least two of your three teammates give you less than 15, your game execution points are scaled by the second highest of their three numbers (15 keeps all, 10 keeps half, 5 or less keeps none). On a team of three, both teammates have to give you less than 15, and the higher number decides. I check the full record first and give you 48 hours to show me work it missed. One teammate alone never changes anybody's grade. The Canvas item has the exact rule.

## Grading Breakdown

| Component | Points | Graded |
| --- | --- | --- |
| Mechanics checkpoint | 10 | Team that wrote it |
| Story checkpoint | 10 | Team that built it |
| Video walkthrough | 35 | Individually |
| Game execution | 20 | Team, subject to the split |
| Post-mortem | 15 | Individually |
| Version control | 10 | Individually, off your own commits |

Any split reduction is applied on the main assignment. Checkpoint grades do not change after they are posted.

### Mechanics checkpoint (10).

| Part | Points | How |
| --- | --- | --- |
| Format | 2 | One mechanic per member of the team you wrote for, each with input, rules, numbers, and win and lose |
| No story | 2 | No setting, characters, story or art |
| Every mechanic changes another | 3 | Minus 1 for each mechanic that changes none, floor 0 |
| Clear enough to build | 3 | Minus 1 for each mechanic the other team marked "had to guess" where I agree your text left it open, floor 0 |

### Story checkpoint (10).

| Part | Points | How |
| --- | --- | --- |
| Premise and beats | 3 | One sentence premise, and every beat placed in the game |
| A reason for every mechanic | 2 | Minus 1 for each mechanic with no reason, floor 0 |
| Found moments | 2 | Three, each with where it is |
| Clarity rating | 2 | Every guess has its question and a specific answer is 2. Some do is 1 |
| Text | 1 | Every planned piece of text and speech, counted |

### Game execution (20) is graded on the final build and the November 4 playtest reports:

| Part | Points | How |
| --- | --- | --- |
| Runs for a stranger | 5 | The link opens in a private window and plays with no instructions |
| Built as written | 4 | Share of mechanics built as written, times 4, rounded to the nearest whole point |
| The story landed | 4 | Share of retellings that name something specific to your premise and at least one beat: all earn 4, more than half 3, half 2, at least one 1 |
| The world tells it | 4 | Share of "found it" answers that name a thing in the world and what it told them about your story: all earn 4, more than half 3, half 2, at least one 1 |
| Art holds together | 3 | Assets agree with each other and with the story |

Over 150 words of text caps game execution at 10 of 20.

Version control counts your commits from October 23 to 4:00 pm November 4: separate working sessions, not the last 48 hours, with messages that say what changed and why. Empty, whitespace-only, and Godot-generated commits (.godot/, .import, the export) do not count. AI-generated assets you wired into the game do. Commits the model made while you drove it count as yours. One commit the night before scores zero.

## Submission Checklist

- Mechanics checkpoint uploaded by every member by 4:00 pm October 23
- Story checkpoint uploaded by every member by October 26
- Live link opening on another machine on October 28
- Final export pushed and rechecked in a private window by 4:00 pm November 4
- Your playtest reports posted on the other team's thread by the end of class on October 28 and November 4
- One PDF to the main assignment: post-mortem, with repo, live, and video links on page one
- Contribution split submitted

| File Name | Size |
| --- | --- |
| Project_4...t (1).pdf | 85.2 KB |
