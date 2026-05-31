# lts Format

## Installing

```bash
quarto use template wjhopper/lts
```

## Using

The `lts` document format is designed for instructors who create coding/data analysis assignments that students complete in Quarto documents. When rendered, an `lts` document produces three outputs instead of just one:

- A lab document: An HTML file containing all the content students need for the assignment
- A template document: A Quarto document with scaffolding for each question in the assignment
- A solutions document: An HTML file showing the desired result for each question and (optionally) the code to produce the results

## Format Options

- `preserve-md`: boolean value controlling whether markdown in the question text is preserved in the template .qmd file. Defaults to true.
- `preserve-chunk-opts`: boolean value controlling whether code chunk options are preserved when code chunks in the lab document are copied into the in the template .qmd file. Defaults to false.
