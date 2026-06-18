-- DropForeignKey
ALTER TABLE "child_word_stats" DROP CONSTRAINT "child_word_stats_child_id_fkey";

-- DropForeignKey
ALTER TABLE "child_word_stats" DROP CONSTRAINT "child_word_stats_word_id_fkey";

-- DropForeignKey
ALTER TABLE "children" DROP CONSTRAINT "children_user_id_fkey";

-- DropForeignKey
ALTER TABLE "quiz_attempts" DROP CONSTRAINT "quiz_attempts_quiz_session_id_fkey";

-- DropForeignKey
ALTER TABLE "quiz_attempts" DROP CONSTRAINT "quiz_attempts_word_id_fkey";

-- DropForeignKey
ALTER TABLE "quiz_sessions" DROP CONSTRAINT "quiz_sessions_child_id_fkey";

-- DropForeignKey
ALTER TABLE "quiz_sessions" DROP CONSTRAINT "quiz_sessions_word_list_id_fkey";

-- DropForeignKey
ALTER TABLE "word_list_items" DROP CONSTRAINT "word_list_items_word_id_fkey";

-- DropForeignKey
ALTER TABLE "word_list_items" DROP CONSTRAINT "word_list_items_word_list_id_fkey";

-- DropForeignKey
ALTER TABLE "word_lists" DROP CONSTRAINT "word_lists_child_id_fkey";

-- DropIndex
DROP INDEX "idx_child_word_stats_next_due";

-- DropIndex
DROP INDEX "idx_quiz_attempts_session";

-- DropIndex
DROP INDEX "idx_quiz_sessions_child";

-- AlterTable
ALTER TABLE "child_word_stats" ALTER COLUMN "difficulty" SET DATA TYPE DOUBLE PRECISION,
ALTER COLUMN "last_practiced_at" SET DATA TYPE TIMESTAMP(3),
ALTER COLUMN "next_due_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "children" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3),
ALTER COLUMN "updated_at" DROP DEFAULT,
ALTER COLUMN "updated_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "quiz_attempts" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "quiz_sessions" ALTER COLUMN "started_at" SET DATA TYPE TIMESTAMP(3),
ALTER COLUMN "completed_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "users" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3),
ALTER COLUMN "updated_at" DROP DEFAULT,
ALTER COLUMN "updated_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "word_lists" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3),
ALTER COLUMN "updated_at" DROP DEFAULT,
ALTER COLUMN "updated_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "words" ADD COLUMN     "tts_audio_base64" TEXT;

-- AddForeignKey
ALTER TABLE "children" ADD CONSTRAINT "children_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "word_lists" ADD CONSTRAINT "word_lists_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "word_list_items" ADD CONSTRAINT "word_list_items_word_list_id_fkey" FOREIGN KEY ("word_list_id") REFERENCES "word_lists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "word_list_items" ADD CONSTRAINT "word_list_items_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "words"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_word_stats" ADD CONSTRAINT "child_word_stats_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_word_stats" ADD CONSTRAINT "child_word_stats_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "words"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_sessions" ADD CONSTRAINT "quiz_sessions_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_sessions" ADD CONSTRAINT "quiz_sessions_word_list_id_fkey" FOREIGN KEY ("word_list_id") REFERENCES "word_lists"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_attempts" ADD CONSTRAINT "quiz_attempts_quiz_session_id_fkey" FOREIGN KEY ("quiz_session_id") REFERENCES "quiz_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_attempts" ADD CONSTRAINT "quiz_attempts_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "words"("id") ON DELETE CASCADE ON UPDATE CASCADE;
