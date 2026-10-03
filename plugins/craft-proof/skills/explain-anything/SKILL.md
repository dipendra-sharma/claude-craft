---
name: explain-anything
description: "Explain any topic — technical, scientific, legal, financial, medical, historical or everyday — so it actually clicks: plain words a beginner can follow, one real-life analogy, and one concrete example carried the whole way through. Use this whenever someone wants to understand a thing rather than be handed a fact: 'teach me X', 'explain X simply', 'help me understand X', 'ELI5 X', 'break X down for me', 'walk me through how X works', 'go deep on X', 'I've never understood X', 'this has never clicked for me', 'I'm new to X, where do I start' — and especially when they describe their own level while asking ('I've run a shop for 20 years and I still don't get input tax credit'). Reach for it even when nobody says the word explain: someone stuck on a concept they cannot hold is the trigger. SKIP quick factual lookups, which want an answer and not an explanation: 'what is X', 'what does this error mean', 'what's the difference between X and Y', 'which should I use' — answer those directly. NEVER load for brainstorming or idea exploration, however deep or unfamiliar the topic: 'let's think through X', 'how should we approach X', 'what are my options for X', 'poke holes in this idea', a design chat, an architecture debate, or weighing two approaches. That is a peer conversation, and the person wants to think alongside you rather than receive an explanation — use design-patterns-best-practices at design time, or no skill at all. Also skip implementation, debugging a concrete bug, code review (coding-best-practices) and API lookup, and hand off to study-track when the ask is a chapter outline or a running course of numbered lesson files across sessions rather than one explanation now."
---

# Explain anything

Make one idea click for someone who has never met it. An explanation is not a summary and not a reference page. The person should be able to explain the thing to a friend afterwards.

The subject does not matter. A database index, a tax credit, an insurance deductible, a court's standard of review, why bread rises, what a central bank actually does when it "raises rates" — they all bend to the same moves, because the hard part is never the subject. The hard part is the gap between what the explainer holds and what the listener holds.

First check that an explanation is wanted. "What's the difference between PUT and PATCH" wants two sentences and nothing more. Explain when the person said "teach me", "I never got this", "go deep", "explain it simply", or described their own level. Otherwise answer the question, then offer: "Want the full picture on this?"

A brainstorm is never an explanation. "Let's think through this", "how should we approach it", "what are my options", "poke holes in this" — those are peer conversations. Drop the explaining voice entirely and think alongside the person. Back out of this skill; do not offer an explanation at the end.

One explanation at a time is the shape here. When someone wants a running course — a chapter outline, or numbered lessons across sessions saved as files, each one tuned to feedback they wrote at the end of the last — that is `study-track`. Hand it over instead of rebuilding it in chat.

## Write for a beginner, always

Assume the person has never met this topic. This is not about being slow or talking down. It is about words. Someone can run a business for twenty years and never have met the word *amortise*. Someone can ship backend code for a decade and never have opened a React file. The moment you use a term they do not hold, the rest of the explanation slides past them — and most people will not stop you to say so.

So the listener is always a smart person with zero background in this one topic:

- Explain every unfamiliar word the first time, in the same sentence or the next one. Yes, including the ones that feel too basic to bother with. The ones that slip through are the ones that feel free to *you*, and every field has its own set:
  - technical: server, request, database, dependency, cache, token, schema, index, thread, port
  - money: liquidity, yield, amortise, basis point, equity, hedge, principal
  - law: consideration, tort, indemnity, jurisdiction, standing, remedy
  - health and science: indication, in vitro, baseline, control group, half-life
  - work and process: deployment, staging, procurement, runway, headcount, escalation
- Spell out an abbreviation once. "TTL (time to live — how long a saved copy stays good)."
- Never explain one unknown thing with another unknown thing. If step 4 needs an idea from nowhere, that idea gets a plain sentence at step 3.
- One new idea per step. A step carrying two ideas is two steps.
- Keep the whole explanation to about five new terms. More than that is a course. Say plainly which parts can wait.
- Run the two passes in *Before you send* at the end. They catch most of the damage.

**Being experienced changes how much ground you cover, never how hard the words are.** Someone senior asking for the mechanism gets more mechanism, in the same plain words. Never write a sentence a beginner could not parse because you think this person can take it.

## Name the thing after they feel it

Give the plain idea first, then attach the real word to it. "The system keeps a copy of the answer nearby so it does not have to ask again — that copy is a **cache**." "The bank charges you for the money you still owe, not the money you borrowed — the money you still owe is the **principal**."

The other order fails quietly. A term dropped before the intuition exists is a label on an empty box, and the listener spends the next paragraph carrying the box instead of following you. In the right order they leave holding both the idea and the word their field actually uses, which is what lets them go read anything else on the subject.

## Depth

Set by how they asked, not by who they are:

- "TLDR", "in short", "ELI5" → definition, analogy, mental model. Stop. Under 400 words.
- "explain X" → the standard template below. Around 600-900 words.
- "teach me", "go deep", "give me the whole picture" → the same template, with the real mechanism inside *How it works*. Longer is allowed here, and only here. "Explain it properly" and "explain it well" are not this — they ask for a good standard explanation, not a longer one.

Match the effort to the difficulty too. A genuinely simple idea explained with a full eight-section structure reads as padding, and the person starts skimming — which costs you their attention on the one hard part later. Easy thing, three sentences. Save the machinery for ideas that are actually counterintuitive.

When it is unclear, assume standard depth and say so in one line. Length is not proof of a good explanation. A longer one usually just means the person stops earlier.

Answer in the language the person wrote in. Pick analogies from a world they live in — a kirana shop or a railway ticket queue lands better for an Indian reader than a US drive-thru.

## Stay inside the question

The second most common failure, after hard words, is explaining a whole field when someone asked about one thing. Extra topics push the real answer down the page and spend attention they needed for the hard part.

- Explain the thing they named. Nothing else gets a section.
- A related idea earns a place only when they cannot follow the main idea without it. Then give it one plain sentence, right where it is needed.
- Everything else goes in one closing line: "Next after this: X." Do not explain X.
- No history, no version timeline, no survey of the field, no list of alternatives, unless they asked.

"Explain database indexes" is about indexes. A B-tree gets a sentence, because an index is one. Sharding and query planners get nothing. "Explain my rent agreement's lock-in clause" is about lock-in. Stamp duty gets nothing.

## Look it up when it can drift

Search when the answer depends on something that changes: a named product, tool, version, price, tax rate, interest rate, law, ruling, or anyone's current role. Explain evergreen things from knowledge — recursion, hash maps, supply and demand, how photosynthesis works, what a deductible is. If you cannot search, say which parts may be out of date.

## Every explanation carries these three

1. **One real-world analogy.** Something ordinary: post, queues, kitchens, keys and locks, a book index, a neighbourhood. Say what maps to what. Then say where it breaks — the break point is the part that teaches. No sharp break point means the analogy is decoration; pick a better one.
2. **One concrete example, and keep it the same one.** A real instance, not a general statement: the actual request, the actual row, the actual ₹40,000 repair bill, the actual clause. Then carry that same example through every section. A fresh example per section resets the listener each time — they stop following the idea and start re-reading the setup. One example that travels the whole way is how the idea accumulates.
3. **One concrete instance of the thing working**, in whatever form the subject has. The smallest one that proves it is real:
   - code → the fewest lines that run
   - money → the actual numbers, worked through
   - law or policy → the actual clause, and one situation it decides
   - health or science → one measurement, or one real case
   - history or society → one dated event
   - a process → one walk-through, start to end

   Prose describing what the instance would look like is not an instance.

The one real branch is notation. Someone who cannot read the field's notation — a non-coder asking about code, a non-lawyer asking about a clause — gets a concrete scenario in plain words instead, because notation they cannot read is a wall, not an example. Everyone else gets the real thing.

Analogy done right — a load balancer:
> A supermarket checkout supervisor. Shoppers arrive, and the supervisor points each one at the shortest line. Nobody picks their own till.
> Mapping: shoppers = requests · tills = servers · supervisor = the load balancer · "shortest line" = the rule it uses.
> Where it breaks: the supervisor can spot a 40-item trolley and send it elsewhere. A load balancer usually cannot tell how heavy a request is before it runs. That is why "least connections" often beats "round robin".

And outside technology — antibiotic resistance:
> Spraying weeds in a garden. The spray kills the weak ones. The survivors reseed, and next season the patch is mostly survivors.
> Mapping: spray = the antibiotic · weeds = bacteria · survivors = resistant strains · next season = the next infection.
> Where it breaks: weeds cannot hand their toughness to a different plant. Bacteria pass resistance genes sideways to species that never met the drug. That is why misusing one antibiotic can wreck a second one.

## Write it simple

- One idea per sentence. Keep it under 20 words.
- Active voice. "The server sends the reply." "The bank keeps the deposit."
- Small words. Use, not utilize. Start, not initiate. About, not approximately. Let, not facilitate.
- One name per thing. Do not swap request → call → hit, or tenant → renter → lessee. To a learner that reads as three things.
- Say "you". "When you call this", not "when the function is invoked by the caller".
- Cut "just", "simply", "obviously", "basically". Each one usually sits on a step you skipped — unpack the step instead.
- No idioms and no clever phrasing. They cost a second reader an extra pass for nothing.
- No filler openers. No "great question", no "let's dive in". Start explaining.
- Be honest when something is hard. Break it into pieces; do not call it easy.

Six sentence shapes to drop, along with their close variants:

- It is not X, it is Y
- It is not about X, it is about Y
- You do not need X, you need Y
- It will not X, it will Y
- The real X is Y
- Less X than Y

Each one sounds sharp and carries almost nothing. The listener spends a beat rejecting a belief they never held, and the useful half of the sentence arrives late. Say the conclusion straight instead. Use cause and effect for a mechanism, a conditional for a boundary, an action sentence for the next step, and a concrete example when two things differ. This is about sentence shape, not about correcting real mistakes — *What people get wrong* names a belief the listener actually holds, and stays.

Simple words are not a thinner answer. Say the true thing, trade-offs included, in small words. The failure on the other side is just as bad: an explanation so smoothed down that it is no longer true. Keep whatever part of the truth is load-bearing, and say plainly when you have left something out.

## Format

- `##` headings for sections. No third level. Never put two headings in a row.
- Bullets for parallel items. Numbers for ordered steps, so they can point at "step 3".
- Bold a key term once, on first use.
- Paragraphs of 2-3 lines.
- One blank line between blocks, never two. No blank lines between bullets.
- A table only when you compare three or more things on the same axes.
- Keep one example in one block. Do not split it into fragments with gaps.
- Plain markdown. No emoji, no ASCII art, no decorative dividers.

## The template

Use the sections that fit and drop the rest. Four to six sections is normal; a quick one lands on three. Running all eight is the sign that you filled the template instead of explaining the topic — every extra section spends words they will not reach. A heading whose content is one sentence belongs in the section above it.

Pick your sections before you write the first sentence, and count them against the ceiling in *Depth*. Cutting a section from a list costs nothing. Cutting it from a finished draft means deleting work you already did, and that almost never happens — the draft ships long instead, which is the single most common way a good explanation loses its reader.

Quick / ELI5:
```
## What is X?      [one line, plus the problem it solves]
## Like this       [analogy with its mapping]
## In short        [one-line mental model]
```

Standard / deep:
```
## What is X?            [one line, then the problem it solves]
## Like this             [analogy: mapping, then where it breaks]
## Where you've seen it  [a real moment or place they have met it]
## How it works          [numbered steps, one new idea per step.
                          For a deep ask, go into the real mechanism
                          here: what it holds, what happens on each
                          event, the clever trick]
## Example               [the smallest real instance — code, numbers,
                          the clause, the case — or a scenario if they
                          cannot read the field's notation]
## When it matters       [where it applies, where it does not, and the
                          main trade-off]
## What people get wrong [name the wrong belief, say it is wrong,
                          replace it, say why it felt true]
## In short              [one-line mental model]
## Check yourself        [1-2 questions, answers right below]
```

## Check yourself

"Does that make sense?" measures nothing — people say yes out of politeness. Ask one or two small questions only someone who got it can answer, and put the answer right below so they can check themselves.

> **Check yourself:** your insurance deductible is ₹10,000 and a repair comes to ₹8,000. You file a claim anyway. What happens?
> *You pay the whole ₹8,000. The insurer pays nothing until the bill passes ₹10,000, so the claim buys you nothing and still sits on your record.*

## Before you send

Two passes over the draft. Both catch things you cannot see while writing, because while writing you hold the whole topic and they do not.

1. **The word pass.** Read the draft as the person you were given. Go noun by noun and find every word they could not define out loud. Expect to find some — "dependency", "principal", "jurisdiction", "baseline" feel free to you and are not. Two kinds hide well: names dropped in passing (Postgres, nginx, SEBI, GDPR, Schedule III) and insider job words (deployment, staging, procurement, discovery, reconciliation). For each one: explain it in four or five words right there, or rewrite the sentence without it. An unexplained word is a bug, not a style choice.
2. **The budget pass.** Count the words against the ceiling in *Depth*. Count prose only — a code block, a table or a worked calculation is not something the reader wades through, it is something they look at. If you picked your sections up front, this is a quick confirmation; if it is turning up a 300-word overshoot, the planning step got skipped. Over the line means delete a whole section — the weakest one, usually a second example or a "what people get wrong" added out of habit. Do not shave adjectives off every sentence. Trimming words makes it dense and still too long; cutting a section makes it shorter and no harder.

When you cut, the analogy and the check-yourself question go last. One builds the idea, and the other is your only evidence it landed — an explanation that drops both is back to being a summary, which is the thing this skill exists to avoid.

## After the explanation

Close by asking for three things in one line: what landed, what did not, and what they want opened up. Never "does that make sense" — people say yes out of politeness.

What comes back sets the next reply:

| What they say | What you do next |
|---|---|
| Lost, ideas tangled, lots of questions | Drop the abstraction, add examples, slow down |
| Got it, but it felt dull | Change the angle, tie it to a real problem of theirs |
| Got it, and asked how to use it | Cases, judgment calls, where it fits and where it does not |
| Clearly holds it | Raise the density, go one layer down |
| Asked something specific | Answer that first, then move on |
| Barely anything | Hold the level, one small step |

"Wait, what's a socket?" is its own signal: you used a word you did not explain. Fill that gap, then carry on.

Build on what they now hold instead of re-explaining it. Answer the follow-up they asked, nothing wider. A sharp follow-up buys more ground, never harder words.
