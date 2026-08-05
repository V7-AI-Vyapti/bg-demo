import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Inject } from '@nestjs/common';
import { DataSource } from 'typeorm';
import type { Job } from 'bullmq';
import { bulk_insert_entity_records } from '@vyapti/core';
import { multiply } from '@vyapti/function-registry';
import {
    bindUpdateProcessStatus,
    getFileById,
    getFileMetaByFileId,
    PROCESS_STATUS,
    runWithProcessStatus,
} from '@vyapti/core/file-ingest-tool-utils';
import { downloadFileBuffer } from '@vyapti/file-storage';
import { readString } from '@vulcan/shared/utils/record-readers';

type MyToolFileIngestJobData = {
    process_id: number;
    file_id: number;
};

const MY_TOOL_FILE_INGEST_QUEUE = 'data_ingestion_my_tool_file_ingest';
const MY_TOOL_FILE_INGEST_JOB = 'file_ingest_protocol_my_tool_file_ingest_data';

@Processor(MY_TOOL_FILE_INGEST_QUEUE)
export class MyToolFileIngestWorker extends WorkerHost {
    constructor(
        @Inject(DataSource)
        private readonly dataSource: DataSource,
    ) {
        super();
    }

    async process(job: Job<MyToolFileIngestJobData>): Promise<void> {
        if (job.name !== MY_TOOL_FILE_INGEST_JOB) {
            return;
        }

        const updateProcessStatusForJob = bindUpdateProcessStatus({
            dataSource: this.dataSource,
        });

        await runWithProcessStatus({
            job: job,
            task: this.runMyToolFileIngest.bind(this),
            updateProcessStatus: updateProcessStatusForJob,
            runningStatus: PROCESS_STATUS.RUNNING,
            successStatus: PROCESS_STATUS.SUCCESS,
            failedStatus: PROCESS_STATUS.FAILED,
        });
    }

    private async runMyToolFileIngest(
        job: Job<MyToolFileIngestJobData>,
    ): Promise<Record<string, unknown>> {
        const { file_id: fileId } = job.data;

        const file = await getFileById({
            fileId: fileId,
            dataSource: this.dataSource,
        });
        const fileMeta = await getFileMetaByFileId({
            fileId: fileId,
            dataSource: this.dataSource,
        });
        const storagePath = readString(fileMeta, 'storage_path');
        const bucketName = readString(fileMeta, 'bucket_name');
        const fileBuffer = await downloadFileBuffer({
            storagePath: storagePath,
            bucketName: bucketName,
        });
        const fileContent = fileBuffer.toString('utf-8');

        // generated tool_details chain
        let step1_result = multiply({ a: 2, b: 3 });

        await bulk_insert_entity_records({
            dataSource: this.dataSource,
            entityName: 'custome',
            data: step1_result,
        });

        return {
            file_id: fileId,
            file_name: readString(file, 'file_name'),
            ingested_record_count: Array.isArray(step1_result)
                ? step1_result.length
                : 1,
        };
    }
}

export { MY_TOOL_FILE_INGEST_QUEUE, MY_TOOL_FILE_INGEST_JOB };
