import { Module } from '@nestjs/common';
import { FileIngestToolsModule } from '@available-tools/file-ingest-tools/file-ingest-tools.module';

@Module({
    imports: [FileIngestToolsModule],
})
export class GeneratedIngestApiModule {}
