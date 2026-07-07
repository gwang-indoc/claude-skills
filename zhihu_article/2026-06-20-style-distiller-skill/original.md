做了一个蒸馏作家文章写作风格的skill 
# Style Distiller

## Description

Use this skill when the user wants to distill an author's writing style from sample articles.

When this skill is invoked, automatically read all supported text files from the `samples/` directory and create a `style.md` file that summarizes the author's writing style.

The user does not need to manually paste the articles.

## What This Skill Does

This skill only does one thing:

Read articles from ./samples/
Analyze the writing style
Output the style profile to ./style.md

It does not rewrite articles.
It does not generate new articles.
It only distills the writing style into a reusable markdown file.
