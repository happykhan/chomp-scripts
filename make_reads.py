import os 
import sys 
import argparse
import logging 

def main(args):
    with open(args.samplenames) as f:
        print("name,r1,r2")
        path = args.path
        for l in f.readlines():
            x = l.strip()
            r1 = os.path.join(os.path.abspath(path), x + '_1.fastq.gz')
            r2 = os.path.join(os.path.abspath(path), x + '_2.fastq.gz')
            if os.path.exists(r1) and os.path.exists(r2):
                 print("%s,%s,%s" %(x, r1, r2))
            else:
                 print(x,  file=sys.stderr)


if __name__ == "__main__":
    logging.basicConfig()
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--samplenames', help='file of samplenames', default='samplenames.txt')
    parser.add_argument('-p', '--path', help='Sample path')  
    parser.add_argument('-v', '--verbose', help='verbose') 
    args = parser.parse_args()
    main(args)
                

