#!/bin/bash
set -e 
#set -x 

source "`dirname ${BASH_SOURCE[0]}`/../bash/common.sh"

log()
{
  echo "### `date` >> $1"
}

usage()
{
  [ ".$1" != "." ] && echo "ERROR: $1"
  echo "usage: `basename $0` -f fasta_ref_file <bam1 .. bamN>"
  exit 0
}

while getopts "f:h" OPTION
do
  case $OPTION in
    f)
      fasta_file=$OPTARG
      ;;
    ?)
      usage
      exit 2
      ;;
  esac
done
shift $(($OPTIND - 1))

[ ".$fasta_file" = "." ] && usage "Need a fasta file."
[ ! -f "$fasta_file" ] && usage "Fasta file: <$fasta_file> not found"
input_bams=""
for b in $@; do
  [ ! -f $b ] && usage "bam: <$b> not found."
  input_bams="$input_bams $b" 
done

# The input bams should have the RG tag set. That's crucial for the
# duplication step where reads coming from the same template as marked
# as PCR duplicates.
# 
#log "Copying bams over"
#local_bams=""
#for b in $input_bams;do
#  base=`basename $b`
#  cp $b ./$base
#  local_bams="$local_bams $base"
#done

# We run a couple of fixes here:
#
# 1. PICARD's fixmate: BWA does not properly set the pairing information
#    fields. 
# 2. BWA can align a read to the junction of two contigs. 
#    There are two cases:
#    A. The read truly maps to that end of the read and the end does not map
#       to the start of the other contig. BWA _does_ NOT set the unmapped 
#       flag. 
#    B. If the read maps to both contigs, BWA sets the unmapped flag but 
#       keeps the CIGAR.
#
#   For case A (mapped), we will recive an error from PICARD since the read is expanding 
#   two contings. 
#   
#   For case B (unmapped), we clean up the CIGAR, otherwise picard complains. 
#       
#log "Fix bam"
#for b in $local_bams;do
#  fix_bam.sh $b | bash
#done

# Merge BAMS
# Merge alignment from the same sample in one single bam
#
n_bams=`echo $input_bams | wc | awk '{print $2}'`
merged_bam="merged.bam"
if [ $n_bams -gt 1 ] ;then
  log "Merge bams ($input_bams)"
  merge_this $input_bams $merged_bam | bash

  log "Verifying #reads in single bams == #reads merged bam"
  n_reads=0
  for b in $input_bams; do
    tmp=`samtools view $b | wc -l`
    n_reads=$[$n_reads+$tmp]
  done
  n_reads_merged_bam=`samtools view $merged_bam | wc -l`
  if [ $n_reads -ne $n_reads_merged_bam ];then
    log "Bailing out: (Single);$n_reads != (Merged);$n_reads_merged_bam"  
  else
    log "# of reads match. Good."
  fi
else
  log "No need to merge, input is a single bam"
  merged_bam=$input_bams
fi

# Mark duplicates. 
#
log "mark dups"
merged_dups_bam="merged.dups.bam"
bam_mark_dups.sh $merged_dups_bam $merged_bam | bash

log "removing merged bam"
[ $n_bams -gt 1 ] && rm -f $merged_bam # Be a good neighbour

# Call snps
#
# 1. Perform pileup and call consensus (SOAP model)
# 2. filter 1 the output: 
#  d: low depth
#  D: high depth
#  W: too many SNPs in a window (SNP only)
#  G: close to a high-quality indel (SNP only)
#  Q: low root-mean-square (RMS) mapping quality (SNP only)
#  g: close to another indel with more evidence (indel only)
# 3. filter 2: SNPQ
#
log "pileup"
pileup.this.sh $merged_dups_bam $fasta_file | bash

base_cov="base_coverage.txt"
log "calculating base coverage"
std_pileup $merged_dups_bam > $base_cov

log "Dist of coverage data"
dist_coverage_txt_json.sh $merged_dups_bam

log "mapping stats"
dbamstats $merged_dups_bam | dbamstats2json.rb

log "insert size distribution stats"
isize_bam_json.sh $merged_dups_bam

log "SNP stats"
output="stats_snps.json"
snp_stats.rb $base_cov *.var_filter.qual_threshold > $output

log "Done."
