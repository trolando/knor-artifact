#!/usr/bin/Rscript
suppressPackageStartupMessages(library('tidyverse'))
suppressPackageStartupMessages(library('ggplot2'))
suppressPackageStartupMessages(library('tikzDevice'))
suppressPackageStartupMessages(library('xtable'))
suppressPackageStartupMessages(library('lemon'))
suppressPackageStartupMessages(library('knitr'))
suppressPackageStartupMessages(library('scales'))

##
## READ the input data
##

cat("Reading results.csv\n")

# Read input data
input <- read_delim('results.csv', delim=";", col_names=FALSE, trim_ws=TRUE, col_types="ccdiiddddddddiii")
# Set column names
colnames(input) <- c("Model", "Solver", "Time", "Done", "Gates", "ParsingTime", "ConstructingTime", "SolvingTime", "PostprocessingTime", "MinimisingTime", "EncodingTime", "CompressingTime", "DRewritingTime", "States", "Vertices", "Edges")

##
## Analyze different GAME CONSTRUCTIONS (naive, explicit, symbolic)
##

# For each Model-Solver combination, we want to extract the number of vertices
# However we want to filter to only get the naive/half-symbolic/symbolic versions
constructing <- input %>%
  select(Model, Solver, Done, Vertices, Edges, Time=ConstructingTime) %>%
  filter(Solver %in% c("std", "std-naive", "std-explicit")) %>%
  group_by(Model, Solver) %>%
  summarize(Done = max(Done), Vertices = max(Vertices), Edges = max(Edges), Time = median(Time), .groups='drop')

sizes <- constructing %>%
  select(Model, Solver, Vertices) %>%
  spread(Solver, Vertices) %>%
  relocate(`std-naive`, .after=Model) %>%
  relocate(`std-explicit`, .after=`std-naive`) %>%
  # Sort descending on std-naive, but place values 0 even higher
  mutate(`std-naive` = ifelse(`std-naive` == 0, Inf, `std-naive`)) %>%
  arrange(desc(`std-naive`)) %>%
  mutate(`std-naive` = ifelse(`std-naive` == Inf, 0, `std-naive`))

cat("Table 1: biggest models (explicit, half-symbolic, symbolic)\n")

kable(sizes %>% head(14),format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))

# Now remove models that have not been done
constructing <- constructing %>% filter(Done == 1) %>% select(-Done)

sum_sizes <- constructing %>%
  select(Model, Solver, Vertices) %>%
  spread(Solver, Vertices) %>%
  drop_na() %>%
  gather(Solver, Vertices, `std`, `std-naive`, `std-explicit`) %>%
  group_by(Solver) %>%
  summarize(Vertices = sum(Vertices))

sum_times <- constructing %>%
  select(Model, Solver, Time) %>%
  spread(Solver, Time) %>%
  drop_na() %>%
  gather(Solver, Time, `std`, `std-naive`, `std-explicit`) %>%
  group_by(Solver) %>%
  summarize(Time = sum(Time))

cat("Table 2: total number of vertices excluding timeout models (explicit, half-symbolic, symbolic)\n")

kable(inner_join(sum_sizes, sum_times),format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))

# Get number of models where the explicit generator is smaller than the symbolic generator
sizes <- constructing %>%
  select(Model, Solver, Vertices) %>%
  spread(Solver, Vertices)

cat("Show models where half-symbolic generator is smaller than symbolic generator\n")
sizes %>% filter(`std-explicit` < `std`) %>% mutate(Diff = `std-explicit` - `std`) %>% arrange(desc(Diff)) 
cat("Number of models where half-symbolic generator is smaller/equal/bigger than symbolic generator\n")
sizes %>% filter(`std-explicit` < `std`) %>% nrow
sizes %>% filter(`std-explicit` == `std`) %>% nrow
sizes %>% filter(`std-explicit` > `std`) %>% nrow
cat("Number of models where naive generator is smaller/equal/bigger than symbolic generator\n")
sizes %>% filter(`std-naive` < `std`) %>% nrow
sizes %>% filter(`std-naive` == `std`) %>% nrow
sizes %>% filter(`std-naive` > `std`) %>% nrow
cat("Show models where half-symbolic is much larger than symbolic\n")
sizes %>% mutate(Diff = `std-explicit` - `std`) %>% arrange(desc(Diff)) %>% head(10)
cat("Show models where explicit is larger than half-symbolic\n")
sizes %>% mutate(Diff = `std-naive` - `std-explicit`) %>% arrange(desc(Diff)) %>% head(10)

##
## Summarize the data (post translation)
##

CompletedModels <- input %>%
  select(Model, Solver, Time) %>%
  filter(!Solver %in% c("std-naive", "std-explicit")) %>%
  group_by(Model, Solver) %>%
  summarize(Time = median(Time), .groups='drop') %>%
  spread(Solver, Time) %>%
  drop_na() %>%
  pull(Model)

cat("Display number of fully completed models (using symbolic translation) -- should be 288\n")
length(CompletedModels)

# Collect data (only of completed models, only using symbolic translation)
data <- input %>%
  group_by(Model, Solver) %>%
  filter(!Solver %in% c("std-naive", "std-explicit")) %>%
  filter(Model %in% CompletedModels) %>% 
  summarize(Time = median(Time), Gates = median(Gates),
            ParsingTime = median(ParsingTime), ConstructingTime = median(ConstructingTime),
            SolvingTime = median(SolvingTime), PostprocessingTime = median(PostprocessingTime),
            MinimisingTime = median(MinimisingTime), EncodingTime = median(EncodingTime),
            CompressingTime = median(CompressingTime),
            DRewritingTime = median(DRewritingTime),
            States = max(States), Vertices = max(Vertices), Edges = max(Edges), .groups = 'drop')

# Now summarize the data per "solver" (combination of options)
sums <- data %>%
  group_by(Solver) %>% summarize(Time = sum(Time), Gates = sum(Gates),
                                 ParsingTime = sum(ParsingTime), ConstructingTime = sum(ConstructingTime),
                                 SolvingTime = sum(SolvingTime), PostprocessingTime = sum(PostprocessingTime),
                                 MinimisingTime = sum(MinimisingTime), EncodingTime = sum(EncodingTime),
                                 CompressingTime = sum(CompressingTime),
                                 DRewritingTime = sum(DRewritingTime),
                                 States = sum(States), Vertices = sum(Vertices), Edges = sum(Edges))

##
## COMPARE different SOLVERS: tl (std), pp, psi, zlk, fpi, fpj and purely BDD solver (fpi)
## We consider: total solving time, number of gates in the end (without optimizations)
##

# Filter data and summarize per model
solving <- input %>%
  select(Model, Solver, Gates, Time=SolvingTime) %>%
  filter(Solver %in% c("std", "sym", "pp", "psi", "zlk", "fpi", "fpj", "std-onehot", "sym-onehot", "pp-onehot", "psi-onehot", "zlk-onehot", "fpi-onehot", "fpj-onehot")) %>%
  group_by(Model, Solver) %>%
  summarize(Gates = median(Gates), Time = median(Time), .groups='drop')

gates <- solving %>%
  select(Model, Solver, Gates) %>%
  spread(Solver, Gates) %>%
  drop_na() %>%
  gather(Solver, Gates, `std`, `sym`, `pp`, `psi`, `zlk`, `fpi`, `fpj`, `std-onehot`, `sym-onehot`, `pp-onehot`, `psi-onehot`, `zlk-onehot`, `fpi-onehot`, `fpj-onehot`)

times <- solving %>%
  select(Model, Solver, Time) %>% 
  spread(Solver, Time) %>%
  drop_na() %>%
  gather(Solver, Time, `std`, `sym`, `pp`, `psi`, `zlk`, `fpi`, `fpj`, `std-onehot`, `sym-onehot`, `pp-onehot`, `psi-onehot`, `zlk-onehot`, `fpi-onehot`, `fpj-onehot`)

sum_gates <- gates %>%
  group_by(Solver) %>%
  summarize(Gates = sum(Gates))

sum_times <- times %>%
  group_by(Solver) %>%
  summarize(Time = sum(Time))

cat("Table 3: Compare different solvers (with binary/onehot encoding)\n")

kable(inner_join(sum_gates, sum_times),format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))

# Now consider all models that require more than 0.5 seconds for symbolic solving

more_than_half_second <- times %>%
  spread(Solver, Time) %>%
  select(Model, `std`, `sym`, `pp`, `psi`, `zlk`, `fpi`, `fpj`) %>%
    filter((`sym` > 0.5) | (`psi` > 0.5)) %>%
    arrange(desc(`sym`)) %>% head(10)

cat("Table 4: Which models required more than 500 ms to solve\n")

kable(more_than_half_second,format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))

##
## MAKE CACTUS PLOT OF SIZE
##

# Helper function that adds cumulative sum of the given solver for time...
CalcCumSum <- function(s, slvr) {
  s = s[s$Solver==slvr,]
  s = s[order(s$Time),]
  s$cumsum <- 1:nrow(s)
  s
}

# Helper function that creates the plots...
Plot <- function(s, slvrs) {
  data <- data.frame(Set = character(0), Model = character(0), Solver = character(0), Time = numeric(0))
  for (slvr in slvrs) { data = rbind(data, CalcCumSum(s, slvr)) }
  ggplot(data, aes(y=Time,x=cumsum,color=Solver,shape=Solver)) +
    geom_point(size=3) + geom_line() +
    #scale_y_continuous(name="Time (sec)") +
    #scale_x_continuous(name="Model count") +
    theme_bw(base_size=16)
}

# Helper function to make the TIKZs
MakeTIKZ = function(s,w,h,t) {
  tikz(s, width=w, height=h, standAlone=F)
  print(t)
  graphics.off()
}

MakePNG = function(s,t) {
  png(s, width=1000, height=1000, res=100)
  print(t)
  graphics.off()
}

data_to_plot <- gates %>%
  filter(Solver %in% c("std", "sym", "pp", "psi", "zlk", "fpi", "fpj")) %>%
  rename("Time"="Gates")

cactus_gates <- Plot(data_to_plot, c("std", "sym", "pp", "psi", "zlk", "fpi", "fpj")) +
  # scale_y_log10(name="Circuit size (gates)", limits=c(0.0001,100000000)) +
  scale_y_continuous(name="Circuit size (gates)") +
  scale_x_continuous(name="Model count") +
  scale_shape_manual(values=1:7) + 
  coord_cartesian(xlim = c(275,290), ylim=c(100,300000))

data_to_plot <- times %>%
  filter(Solver %in% c("std", "sym", "pp", "psi", "zlk", "fpi", "fpj"))

cactus_times <- Plot(data_to_plot, c("std", "sym", "pp", "psi", "zlk", "fpi", "fpj")) +
  scale_y_log10(name="Time (sec)", limits=c(0.0001,100),
                breaks=c(0.0001,0.001,0.01,0.1,1,10),
                labels=c("0.1ms","1ms","10ms","0.1s","1s","10s")) +
  # scale_y_continuous(name="Circuit size (gates)") +
  coord_cartesian(xlim = c(200,290), ylim=c(0.0001,10)) + 
  # scale x break every 5 minor and every 10 major
  scale_x_continuous(name="Model count", breaks = seq(200, 290, 10), minor_breaks = seq(200, 290, 5)) +
  # friendlier names for legend (solvers)
  #scale_shape_manual(values=1:7, labels=c("tangle learning","symbolic fpi","priority promotion","strategy iteration","Zielonka","FPI","FPJ")) +
  #scale_color_manual(values=1:7, labels=c("fixpoint (freezing)","fixpoint (justifications)","priority promotion","strategy iteration","tangle learning","symbolic fpi","Zielonka"))
  scale_shape_manual(values=1:7, labels=c("fpi","fpj","pp","psi","tl","sym","zlk")) +
  scale_color_manual(values=1:7, labels=c("fpi","fpj","pp","psi","tl","sym","zlk"))

cat("Figure 4 in cactus_solver_times.tex and cactus_solver_times.png\n")

# Plot the result with MakeTIKZ
MakeTIKZ("cactus_solver_times.tex", 8, 3, cactus_times)
MakePNG("cactus_solver_times.png", cactus_times)

##
## BISIMULATION
##

res <- sums %>%
  filter(Solver %in% c("sym", "sym-bisim", "sym-onehot", "sym-bisim-onehot",
                       "fpj", "fpj-bisim", "fpj-onehot", "fpj-bisim-onehot")) %>%
  select(Solver, Gates, Time=MinimisingTime) %>% arrange((Gates))

cat("Table 5: Bisimulation results\n")

kable(res,format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))

bisim <- data %>%
  filter(Solver %in% c("sym", "sym-bisim", "sym-onehot", "sym-bisim-onehot",
                       "fpj", "fpj-bisim", "fpj-onehot", "fpj-bisim-onehot")) %>%
  select(Model, Solver, Gates) %>%
  spread(Solver, Gates) %>%
  mutate(`sym-onehot-diff` = `sym-bisim-onehot` - `sym-onehot`) %>%
  mutate(`fpj-onehot-diff` = `fpj-bisim-onehot` - `fpj-onehot`) %>%
  mutate(`sym-bisim-diff` = `sym-bisim` - `sym`) %>%
  mutate(`fpj-bisim-diff` = `fpj-bisim` - `fpj`) %>%
  # only keep diff > 0
  filter(`sym-onehot-diff` > 0 | `fpj-onehot-diff` > 0 | `sym-bisim-diff` > 0 | `fpj-bisim-diff` > 0) 

## Look at the bisim table to dive into the results

##
## ENCODING to AIG
##

res <- sums %>%
  filter(Solver %in% c("sym-bisim", "sym-bisim-onehot", "sym-bisim-isop", "sym-bisim-isop-onehot",
                       "fpj-bisim", "fpj-bisim-onehot", "fpj-bisim-isop", "fpj-bisim-isop-onehot")) %>%
  select(Solver, Gates, Time=EncodingTime) %>% arrange((Gates))

cat("Table 6: Encoding results\n")

kable(res,format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))

# Look at individual cases (ISOP vs ITE)
encoding <- data %>%
  filter(Solver %in% c("sym-bisim", "sym-bisim-onehot", "sym-bisim-isop", "sym-bisim-isop-onehot",
                       "fpj-bisim", "fpj-bisim-onehot", "fpj-bisim-isop", "fpj-bisim-isop-onehot")) %>%
  select(Model, Solver, Gates) %>%
  spread(Solver, Gates) %>%
  mutate(`sym-bisim-diff` = `sym-bisim-isop` - `sym-bisim`) %>%
  mutate(`fpj-bisim-diff` = `fpj-bisim-isop` - `fpj-bisim`) %>%
  mutate(`sym-bisim-onehot-diff` = `sym-bisim-isop-onehot` - `sym-bisim-onehot`) %>%
  mutate(`fpj-bisim-onehot-diff` = `fpj-bisim-isop-onehot` - `fpj-bisim-onehot`) 

# Inspect the encoding table to do a deeper analysis
  
##
## Now: postprocessing
##

res <- sums %>%
  filter(Solver %in% c("sym-bisim-onehot", "sym-bisim-isop-onehot",
                       "sym-bisim-onehot-compress", "sym-bisim-isop-onehot-compress",
                       "sym-bisim-onehot-drewrite", "sym-bisim-isop-onehot-drewrite",
                       "fpj-bisim-onehot", "fpj-bisim-isop-onehot",
                       "fpj-bisim-onehot-compress", "fpj-bisim-isop-onehot-compress",
                       "fpj-bisim-onehot-drewrite", "fpj-bisim-isop-onehot-drewrite")) %>%
  select(Solver, Gates, Time=Time) %>% arrange((Gates))

cat("Table 7: Postprocessing results\n")

kable(res,format="latex",booktabs=TRUE,linesep="",digits=2,format.args = list(big.mark = ","))
