DS_CONFIG=./examples_deepspeed/finetune_hf_llama/ds_config.json
DATASET_PATH=./alpaca_data.json
# dataset link: https://github.com/tatsu-lab/stanford_alpaca/blob/main/alpaca_data.json

HF_LLAMA_PATH=../../../../../persistentshare/storage/team_kawagoshi/tinny_llama
# weights link: https://huggingface.co/huggyllama/llama-7b


num_workers=0
GPUS_PER_NODE=1

MICRO_BATCH_SIZE=16
GLOBAL_BATCH_SIZE=256
TP=1
PP=1
# require to align with weight dimensions
HIDDEN_SIZE=4096
FFN_HIDDEN_SIZE=11008
NUM_LAYERS=32
NUM_HEADS=32
SEQ_LENGTH=4096
NUM_KV_HEADS=32
######################################

MEGA_DS_LLAMA_PATH="../../../../../persistentshare/storage/team_kawagoshi/llama-7b-mega-ds-T${TP}P${PP}"

# Below configuration required for llama model as per llama paper
# --no-query-key-layer-scaling \
# --attention-dropout 0 \
# --hidden-dropout 0 \
# --use-rotary-position-embeddings \
# --untie-embeddings-and-output-weights \
# --swiglu \
# --normalization rmsnorm \
# --disable-bias-linear \
######################################
cat <<EOT > $DS_CONFIG
{
  "train_batch_size" : $GLOBAL_BATCH_SIZE,
  "train_micro_batch_size_per_gpu": $MICRO_BATCH_SIZE,
  "steps_per_print": 100,
  "zero_optimization": {
    "stage": 0
  },
  "bf16": {
    "enabled": true
  }
}
EOT


covert_args="deepspeed tools/hf2megads_weight_converter.py \
--hf-ckpt-num-shards 1 \
--origin-hf-ckpt-dir $HF_LLAMA_PATH \
--save $MEGA_DS_LLAMA_PATH"

finetune_args="deepspeed finetune_llama.py \
--load $MEGA_DS_LLAMA_PATH"

comm_args="--tensor-model-parallel-size $TP \
--pipeline-model-parallel-size $PP \
--lr-warmup-iters 2000 \
--weight-decay 0.1 \
--clip-grad 1 \
--num-layers $NUM_LAYERS \
--hidden-size $HIDDEN_SIZE \
--num-attention-heads $NUM_HEADS \
--ffn-hidden-size $FFN_HIDDEN_SIZE \
--num-key-value-heads $NUM_KV_HEADS \
--attention-dropout 0 \
--hidden-dropout 0 \
--no-query-key-layer-scaling \
--disable-bias-linear \
--normalization rmsnorm \
--use-rotary-position-embeddings \
--untie-embeddings-and-output-weights \
--swiglu \
--seq-length $SEQ_LENGTH \
--max-position-embeddings $SEQ_LENGTH \
--micro-batch-size $MICRO_BATCH_SIZE \
--global-batch-size $GLOBAL_BATCH_SIZE \
--train-iters 3500 \
--lr 2e-5 \
--tensorboard-dir tensorboard_output \
--lr-decay-iters 320000 \
--lr-decay-style cosine \
--log-interval 1 \
--eval-iters 100 \
--eval-interval 100 \
--data-path $DATASET_PATH \
--save-interval 1500 \
--split 100,0,0 \
--bf16 \
--zero-stage 0 \
--tokenizer-type HFTokenizer \
--tokenizer-model $HF_LLAMA_PATH \
--deepspeed_config ./examples_deepspeed/finetune_hf_llama/ds_config.json \
--deepspeed \
--distributed-backend nccl \
--num-workers 0 \
--no-masked-softmax-fusion \
--no-bias-gelu-fusion \
--no-bias-dropout-fusion \
--no-gradient-accumulation-fusion \
--repeated-dataloader \
--no-query-key-layer-scaling \
--attention-dropout 0 \
--hidden-dropout 0 \
--use-rotary-position-embeddings \
--untie-embeddings-and-output-weights \
--swiglu \
--normalization rmsnorm \
--disable-bias-linear 
--hf-ckpt-num-shards 1 \
--origin-hf-ckpt-dir $HF_LLAMA_PATH \
--save $MEGA_DS_LLAMA_PATH "

GPUS_PER_NODE=1
MASTER_ADDR=localhost
MASTER_PORT=6000
NNODES=1
NODE_RANK=0

DISTRIBUTED_ARGS="--nproc_per_node $GPUS_PER_NODE --nnodes $NNODES --node_rank $NODE_RANK --master_addr $MASTER_ADDR --master_port $MASTER_PORT"

if [ "$1" = "convert" ]; then
    task_args="$covert_args"
else
    task_args="$finetune_args"
fi

full_cmd="$task_args $comm_args"

export MASTER_PORT=29501

training_script="tools/hf2megads_weight_converter.py"

#python -m torch.distributed.launch \
#    --DISTRIBUTED_ARGS \
#    $training_script $task_args $comm_args

torchrun $DISTRIBUTED_ARGS \
    tools/hf2megads_weight_converter.py \
    $comm_args

#eval "$full_cmd"

