import random
import string
import nltk
nltk.download('words')
from nltk.corpus import words

def username(max_len):
    s = ""
    w = [x for x in words.words() if 4 <= len(x) <= 8]
    while len(s) == 0 or len(s) > max_len:
        s = random.choice(("", "_")).join(random.choice(w) for _ in range(random.randint(2, 4)))
        if random.random() > 0.7:
            s += ''.join(random.choice(string.digits) for _ in range(random.randint(2, 4)))
    return s


print(username(20))
