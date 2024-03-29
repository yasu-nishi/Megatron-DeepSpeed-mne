import json
import sys
from datasets import load_dataset

if __name__ == "__main__":
    dataset = load_dataset('mc4', 'ja', split='train', streaming=True)
    limit = int(sys.argv[1])
    count = 0
    for doc in dataset:
        json.dump(doc, sys.stdout, ensure_ascii=False)
        print()
        count += 1
        if count == limit:
            break