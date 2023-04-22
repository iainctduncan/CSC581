# Activity Report for ScmSeq 

## Reflections and Learnings
* Going through the log is useful as a way to see work habits - I should make an effort to do smaller, more frequent commits
  with better messages even if it's just me
* Even though I make an effort in this area, my notes to self could still be a lot better!!
* I have a work log file, but am not good at using it consistently. A stronger effort here would be worthwhile,
  it's very useful to be able to look back over what I was thinking and doing when I get to resume after a week away
* I think a mental bad habit I have is of thinking I don't need to end the day with a commit or good notes
  as I'm sure I'll be picking it up again the next day, but then some other life/work surprise happens, and I don't get
  back to this work for four or five days and have to waste a bunch of time figuring out what was loaded in my head
* Plus I could lose work this way in the event of a disk failure ....
* Worth thinking about what will go in which repositories better ahead of time
* The process of writing demo documentation was helpful - it did make me find some rough edges and design flaws
* The process of making a top to bottom video was also helpful in finding design flaws or things that need to be easier 

## Log 
This is an incomplete report as unfortunately I was lost some commit history
in moving things between repositories and was also not good about committing each day

* 2023-02-23
    * Worked on the seq setup code, how we make files that start out template seqs

* 2023-02-24
    * Further work on the seq setup code, got it to decent place

* 2023-02-25
    * Worked on Drum mode, created controller for it, did mappings
    * Got basic drum mode writing happening

* 2023-02-26
    * Worked on Drum mode, params and velocity writing
    * Added choosing pitch from second keyboard

* 2022-02-27:
    * Worked on Drum mode and docs for it, added meta keys
    * Added ability to change controllers by putting into a hot settings bank, controlled by pedal
    * Added short cut erasing tools

* 2022-02-28: 
    * Worked on the routing and Live setup for drums - all seqs route to one AD2 channel
    * Got large number (12) of sequencers playing together, am close to GC issues
        * maybe worth rewriting drum seqs in C?

* 2022-03-01:
    * Worked on full workflow for step mode
    * Added erasing and duration handling to step mode
    * Added using modwheel and bend for step mode

* 2022-03-03 
    * started on Perform mode, grid buttons setting loop lengths
    * Came up with way for grid pads to have submodes controlled by Fire keys
    * Started on Copy mode design, figuring out how selections will work

* 2022-03-04
    * Got step mode basically done
    * Fixes to what the grid does in perform mode
 
* 2022-03-05
    * Perform mode working for loop lengths and muting

* 2022-03-06
    * Got copy mode to the point of selecting targets (not yet copying)
    * Bug fixes to perform and copy

* (there was a whole bunch of work in March that I lost log entries for....)

* 2023-04-02
    * Worked on documentation:  overview, design goals

* 2023-04-03
    * Worked on documentation: user guide, how components work

* 2023-04-05
    * Worked on documentation: mode manuals, implementation

* 2023-04-07
    * Worked on documentation: how seqs work

* 2023-04-14
    * Fixes to perform and copy, can now change a 1 bar loop to 2 relatively easily

* 2023-04-15
    * Created practice set for demo, figured out what should be in demo scope

* 2023-04-16
    * Working on demonstration script and set
    * Fixed bugs in step, perform, and copy modes
    

