## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup, message = FALSE---------------------------------------------------
library(dplyr)
library(dbplyr)

mf <- memdb_frame(x = 1, y = 2)

## -----------------------------------------------------------------------------
mf %>% 
  mutate(
    a = y * x, 
    b = a ^ 2,
  ) %>% 
  show_query()

## -----------------------------------------------------------------------------
mf %>% 
  mutate(z = foofify(x, y)) %>% 
  show_query()

mf %>% 
  filter(x %LIKE% "%foo%") %>% 
  show_query()

## -----------------------------------------------------------------------------
mf %>% 
  transmute(factorial = sql("x!")) %>% 
  show_query()

mf %>% 
  transmute(factorial = sql("CAST(x AS FLOAT)")) %>% 
  show_query()

