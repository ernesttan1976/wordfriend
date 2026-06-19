-- AlterTable
ALTER TABLE "children" ADD COLUMN     "global_difficulty_bias" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "words" ADD COLUMN     "hint_consonants" TEXT,
ADD COLUMN     "hint_first_last" TEXT,
ADD COLUMN     "hint_letter_count" TEXT,
ADD COLUMN     "hint_sentence" TEXT,
ADD COLUMN     "hint_similar" TEXT;
