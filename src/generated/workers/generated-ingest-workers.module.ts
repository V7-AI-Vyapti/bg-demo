import { Module } from '@nestjs/common';
import { FileIngestToolsModule } from '@available-tools/file-ingest-tools/file-ingest-tools.module';
import { GeneratedFileIngestBackgroundWorkersModule } from './generated-file-ingest-background-workers.module';

@Module({
    imports: [
        FileIngestToolsModule,
        GeneratedFileIngestBackgroundWorkersModule,
    ],
})
export class GeneratedIngestWorkersModule {}
