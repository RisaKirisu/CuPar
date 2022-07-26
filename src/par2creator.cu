//  This file is part of par2cmdline (a PAR 2.0 compatible file verification and
//  repair tool). See http://parchive.sourceforge.net for details of PAR 2.0.
//
//  Copyright (c) 2003 Peter Brian Clements
//  Copyright (c) 2019 Michael D. Nahas
//  Copyright (c) 2022 Xiuyan Wu
//
//  par2cmdline is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  par2cmdline is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#include "libpar2internal.h"

#ifdef _MSC_VER
#ifdef _DEBUG
#undef THIS_FILE
static char THIS_FILE[]=__FILE__;
#define new DEBUG_NEW
#endif
#endif

// ProcessData, but on CUDA device.
bool Par2Creator::ProcessDataCu()
{
  // Start at an offset of 0 within a block.
  // Continue until the end of the block.
  u64 blockOffset = 0;
  while (blockOffset < blocksize) {
    // Work out how much data to process this time.
    size_t blockLen = (size_t) min((u64) chunksize, blocksize - blockOffset);

    // Clear the output buffer
    memset(outputbuffer, 0, chunksize * recoveryblockcount);

    // If we have deferred computation of the file hash and block crc and hashes
    // sourcefile and sourceindex will be used to update them during
    // the main recovery block computation
    vector<Par2CreatorSourceFile*>::iterator sourcefile = sourcefiles.begin();
    u32 sourceindex = 0;

    vector<DataBlock>::iterator sourceblock;
    u32 inputIdx;

    DiskFile *lastopenfile = NULL;

    // Read blockLen bytes of each input block into inputbuffer
    for ((sourceblock=sourceblocks.begin()),(inputIdx=0);
        sourceblock != sourceblocks.end();
        ++sourceblock, ++inputIdx)
    {
      // Are we reading from a new file?
      if (lastopenfile != (*sourceblock).GetDiskFile())
      {
        // Close the last file
        if (lastopenfile != NULL)
        {
          lastopenfile->Close();
        }

        // Open the new file
        lastopenfile = (*sourceblock).GetDiskFile();
        if (!lastopenfile->Open())
        {
          return false;
        }
      }

      // Read data from the current input block
      if (!sourceblock->ReadData(blockOffset, blockLen, &((u8*) inputbuffer)[blockLen * inputIdx]))
        return false;

      if (deferhashcomputation)
      {
        assert(blockOffset == 0 && blockLen == blocksize);
        assert(sourcefile != sourcefiles.end());

        (*sourcefile)->UpdateHashes(sourceindex, &((u8*) inputbuffer)[blockLen * inputIdx], blockLen);
      }

      // Work out which source file the next block belongs to
      if (++sourceindex >= (*sourcefile)->BlockCount())
      {
        sourceindex = 0;
        ++sourcefile;
      }
    }

    // Close the last file
    if (lastopenfile != NULL)
    {
      lastopenfile->Close();
    }

    // Process the data through the RS matrix on GPU
    if (!rs.ProcessCu(blockLen, 0, sourceblockcount - 1, inputbuffer, 0, recoveryblockcount - 1, outputbuffer)) {
      return false;
    }

    if (noiselevel > nlQuiet)
    {
      // Update a progress indicator
      u32 oldfraction = (u32)(1000 * progress / totaldata);
      progress += blockLen * sourceblockcount * recoveryblockcount;
      u32 newfraction = (u32)(1000 * progress / totaldata);

      if (oldfraction != newfraction)
      {
        sout << "Processing: " << newfraction/10 << '.' << newfraction%10 << "%\r" << flush;
      }
    }

    // For each output block
    for (u32 outputblock=0; outputblock<recoveryblockcount;outputblock++)
    {
      // Select the appropriate part of the output buffer
      u8 *outbuf = &((u8*) outputbuffer)[blockLen * outputblock];

      // Write the data to the recovery packet
      if (!recoverypackets[outputblock].WriteData(blockOffset, blockLen, outbuf))
        return false;
    }

    if (noiselevel > nlQuiet)
      sout << "Wrote " << recoveryblockcount * blockLen << " bytes to disk" << endl;

    blockOffset += blockLen;
  }

  return true;
}
