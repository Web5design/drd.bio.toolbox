##
# R CMD BATCH "--vanilla --args in.file='data_file' in.o_file='f_name'" < R_code
#
args=(commandArgs(TRUE));
for(i in 1:length(args)){
  eval(parse(text=args[[i]]));
}

pdf(file=in.o_file, height=8, width=5)
par(mfrow=c(1,1))
colors <- c("green", "red", "black")
tools <- c("BFAST", "BWA", "NOVOALIGN")
l_type <- "l"

# Load data 
d <- scan(in.file, what=list(mapq=0, bfast_ok=0, bfast_mapped=0, bwa_ok=0, bwa_mapped=0, novo_ok=0, novo_mapped=0, total=0), skip=1)

bf_tpr       <- (d$bfast_ok/d$total)
bf_fdr       <- 1-(d$bfast_ok/d$bfast_mapped)
log_bf_fdr   <- log10(1-(d$bfast_ok/d$bfast_mapped))
bwa_tpr      <- (d$bwa_ok/d$total)
bwa_fdr      <- 1-(d$bwa_ok/d$bwa_mapped)
log_bwa_fdr  <- log10(1-(d$bwa_ok/d$bwa_mapped))
novo_tpr     <- (d$novo_ok/d$total)
novo_fdr     <- 1-(d$novo_ok/d$novo_mapped)
log_novo_fdr <- log(1-(d$novo_ok/d$novo_mapped))

xrange <- c(0,.15)
yrange <- c(0,1)
#xrange <- c(-5.5,-1.7)

plot(xrange, yrange, type="n",
  xlab="False discovery rate (of mapped, fraction mapped incorrectly)",
  ylab="True positive rate (fraction mapped correctly)")

lines(x=bf_fdr, y=bf_tpr, type=l_type, lwd=1.5, col=colors[1])
lines(x=bwa_fdr, y=bwa_tpr, type=l_type, lwd=1.5, col=colors[2])
lines(x=novo_fdr, y=novo_tpr, type=l_type, lwd=1.5, col=colors[3])

title("Alignment Accuracy")
legend("bottomright", tools , col=colors, lty=1:1:1, cex=1.0)
