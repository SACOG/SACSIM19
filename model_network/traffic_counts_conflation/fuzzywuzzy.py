#KS Notes: 3/28/18

# Fuzzy string matching like a boss. It uses Levenshtein Distance to calculate the differences between sequences in a simple-to-use package.
# https://github.com/seatgeek/fuzzywuzzy/blob/master/README.rst
# https://en.wikipedia.org/wiki/Levenshtein_distance
# Download Levenstein C++ package for faster performance
#   1. https://github.com/ztane/python-Levenshtein/
#   2. https://www.microsoft.com/en-in/download/confirmation.aspx?id=48145
#   3. https://www.visualstudio.com/downloads/#build-tools-for-visual-studio-2017


import os
import sys

sys.path.insert(0,'C:\Program Files\Anaconda3\Lib\site-packages')
from fuzzywuzzy import fuzz
from fuzzywuzzy import process
from Levenshtein import StringMatcher

print("import worked!")

print("testing:")

#Extract One test
#You can also pass additional parameters to extractOne method to make it use a specific scorer. A typical use case is to match file paths:
#in - extract2 = process.extractOne("System of a down - Hypnotize - Heroin", songs)
#out -     ('/music/library/good/System of a Down/2005 - Hypnotize/01 - Attack.mp3', 86)
correct_roadnames = ["Aljunied Avenue 1", "Aljunied Avenue 2"]
score = process.extractOne("Aljuneid Avenue 1", correct_roadnames)
print(score)

#simple ratio
rationtest = fuzz.ratio("this is a test", "this is a test!")
print(rationtest)

#partial raio
partialratio = fuzz.partial_ratio("this is a test", "this is a test!")
print(partialratio)

#token sort ratio
tokensortratio1 = fuzz.ratio("fuzzy wuzzy was a bear", "wuzzy fuzzy was a bear")
toeknsortratio2 = fuzz.token_sort_ratio("fuzzy wuzzy was a bear", "wuzzy fuzzy was a bear")
print(tokensortratio1)
print(toeknsortratio2)

#Token Set Ration
tokensortratio = fuzz.token_sort_ratio("fuzzy was a bear", "fuzzy fuzzy was a bear")
toeknsetratio = fuzz.token_set_ratio("fuzzy was a bear", "fuzzy fuzzy was a bear")
print(tokensortratio)
print(toeknsetratio)

#process
choices = ["Atlanta Falcons", "New York Jets", "New York Giants", "Dallas Cowboys"]
p1 = process.extract("new york jets", choices, limit=2)
p2 = process.extractOne("cowboys", choices)
print(p1)
print(p2)