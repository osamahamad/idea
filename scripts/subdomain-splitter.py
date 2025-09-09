#!/usr/bin/env python3

"""
Subdomain Splitter for Nuclei Mass Scanning
Splits large subdomain lists into manageable batches for GitHub Actions processing
"""

import argparse
import os
import sys
from pathlib import Path
import math

def count_lines(file_path):
    """Count lines in a file efficiently"""
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        return sum(1 for _ in f)

def split_subdomains(input_file, output_dir, batch_size=1000, max_batches=None):
    """Split subdomains into batches"""
    
    input_path = Path(input_file)
    output_path = Path(output_dir)
    
    if not input_path.exists():
        print(f"❌ Input file not found: {input_file}")
        return False
    
    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Count total lines
    print("📊 Counting subdomains...")
    total_subdomains = count_lines(input_file)
    total_batches = math.ceil(total_subdomains / batch_size)
    
    if max_batches and total_batches > max_batches:
        print(f"⚠️  Warning: {total_batches} batches needed, but max_batches is {max_batches}")
        total_batches = max_batches
        effective_subdomains = max_batches * batch_size
        print(f"   Will process first {effective_subdomains} subdomains")
    
    print(f"📈 Total subdomains: {total_subdomains:,}")
    print(f"📦 Batch size: {batch_size}")
    print(f"🔢 Total batches: {total_batches}")
    print()
    
    # Split file
    print("✂️  Splitting subdomains...")
    
    with open(input_file, 'r', encoding='utf-8', errors='ignore') as infile:
        batch_num = 1
        current_batch_size = 0
        current_batch_file = None
        processed_subdomains = 0
        
        for line_num, line in enumerate(infile, 1):
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
            
            # Start new batch if needed
            if current_batch_size == 0:
                if current_batch_file:
                    current_batch_file.close()
                
                batch_filename = output_path / f"batch_{batch_num:04d}.txt"
                current_batch_file = open(batch_filename, 'w', encoding='utf-8')
                print(f"📝 Creating batch {batch_num}: {batch_filename}")
            
            # Write to current batch
            current_batch_file.write(line + '\n')
            current_batch_size += 1
            processed_subdomains += 1
            
            # Close batch if full
            if current_batch_size >= batch_size:
                current_batch_file.close()
                current_batch_file = None
                current_batch_size = 0
                batch_num += 1
                
                # Stop if we've reached max batches
                if max_batches and batch_num > max_batches:
                    break
        
        # Close final batch
        if current_batch_file:
            current_batch_file.close()
    
    actual_batches = batch_num - 1 if current_batch_size == 0 else batch_num
    
    print(f"✅ Successfully created {actual_batches} batch files")
    print(f"📊 Processed {processed_subdomains:,} subdomains")
    print(f"📁 Output directory: {output_dir}")
    
    # Create summary file
    summary_file = output_path / "batch_summary.txt"
    with open(summary_file, 'w') as f:
        f.write(f"Batch Summary\n")
        f.write(f"=============\n")
        f.write(f"Input file: {input_file}\n")
        f.write(f"Total subdomains in input: {total_subdomains:,}\n")
        f.write(f"Processed subdomains: {processed_subdomains:,}\n")
        f.write(f"Batch size: {batch_size}\n")
        f.write(f"Total batches created: {actual_batches}\n")
        f.write(f"Output directory: {output_dir}\n")
        f.write(f"\nBatch files:\n")
        
        for i in range(1, actual_batches + 1):
            batch_file = output_path / f"batch_{i:04d}.txt"
            if batch_file.exists():
                batch_lines = count_lines(batch_file)
                f.write(f"  batch_{i:04d}.txt: {batch_lines:,} subdomains\n")
    
    print(f"📋 Summary saved to: {summary_file}")
    return True

def merge_batches(batch_dir, output_file, batch_pattern="batch_*.txt"):
    """Merge batch files back into a single file"""
    
    batch_path = Path(batch_dir)
    output_path = Path(output_file)
    
    if not batch_path.exists():
        print(f"❌ Batch directory not found: {batch_dir}")
        return False
    
    # Find batch files
    batch_files = sorted(batch_path.glob(batch_pattern))
    
    if not batch_files:
        print(f"❌ No batch files found matching pattern: {batch_pattern}")
        return False
    
    print(f"🔄 Merging {len(batch_files)} batch files...")
    print(f"📁 Output file: {output_file}")
    
    total_lines = 0
    
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for batch_file in batch_files:
            print(f"📝 Processing: {batch_file.name}")
            
            with open(batch_file, 'r', encoding='utf-8', errors='ignore') as infile:
                batch_lines = 0
                for line in infile:
                    line = line.strip()
                    if line:  # Skip empty lines
                        outfile.write(line + '\n')
                        batch_lines += 1
                        total_lines += 1
                
                print(f"   Added {batch_lines:,} subdomains")
    
    print(f"✅ Successfully merged {total_lines:,} subdomains")
    print(f"📄 Output file: {output_file}")
    return True

def validate_subdomains(file_path):
    """Validate subdomain format and provide statistics"""
    
    if not Path(file_path).exists():
        print(f"❌ File not found: {file_path}")
        return False
    
    print(f"🔍 Validating subdomains in: {file_path}")
    
    total_lines = 0
    valid_subdomains = 0
    invalid_lines = []
    duplicates = set()
    seen_subdomains = set()
    
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line_num, line in enumerate(f, 1):
            total_lines += 1
            subdomain = line.strip().lower()
            
            # Skip empty lines
            if not subdomain:
                continue
            
            # Check for duplicates
            if subdomain in seen_subdomains:
                duplicates.add(subdomain)
                continue
            
            seen_subdomains.add(subdomain)
            
            # Basic subdomain validation
            if ('.' in subdomain and 
                not subdomain.startswith('.') and 
                not subdomain.endswith('.') and
                not ' ' in subdomain and
                len(subdomain) > 3):
                valid_subdomains += 1
            else:
                invalid_lines.append((line_num, subdomain[:50]))
    
    print(f"📊 Validation Results:")
    print(f"   Total lines: {total_lines:,}")
    print(f"   Valid subdomains: {valid_subdomains:,}")
    print(f"   Duplicates found: {len(duplicates):,}")
    print(f"   Invalid entries: {len(invalid_lines):,}")
    
    if invalid_lines and len(invalid_lines) <= 10:
        print(f"\n⚠️  Invalid entries (first 10):")
        for line_num, content in invalid_lines[:10]:
            print(f"   Line {line_num}: {content}")
    elif len(invalid_lines) > 10:
        print(f"\n⚠️  Too many invalid entries to display ({len(invalid_lines)} total)")
    
    if duplicates and len(duplicates) <= 5:
        print(f"\n🔄 Duplicate subdomains (first 5):")
        for dup in list(duplicates)[:5]:
            print(f"   {dup}")
    elif len(duplicates) > 5:
        print(f"\n🔄 Too many duplicates to display ({len(duplicates)} total)")
    
    return True

def main():
    parser = argparse.ArgumentParser(
        description="Subdomain Splitter for Nuclei Mass Scanning",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Split subdomains into batches of 1000
  python3 subdomain-splitter.py split subdomains.txt batches/
  
  # Split with custom batch size
  python3 subdomain-splitter.py split subdomains.txt batches/ --batch-size 500
  
  # Limit to first 100 batches (100k subdomains)
  python3 subdomain-splitter.py split subdomains.txt batches/ --max-batches 100
  
  # Merge batch files back
  python3 subdomain-splitter.py merge batches/ merged-subdomains.txt
  
  # Validate subdomain format
  python3 subdomain-splitter.py validate subdomains.txt
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Split command
    split_parser = subparsers.add_parser('split', help='Split subdomains into batches')
    split_parser.add_argument('input_file', help='Input file containing subdomains')
    split_parser.add_argument('output_dir', help='Output directory for batch files')
    split_parser.add_argument('--batch-size', type=int, default=1000, 
                            help='Number of subdomains per batch (default: 1000)')
    split_parser.add_argument('--max-batches', type=int, 
                            help='Maximum number of batches to create')
    
    # Merge command
    merge_parser = subparsers.add_parser('merge', help='Merge batch files')
    merge_parser.add_argument('batch_dir', help='Directory containing batch files')
    merge_parser.add_argument('output_file', help='Output file for merged subdomains')
    merge_parser.add_argument('--pattern', default='batch_*.txt',
                            help='Pattern for batch files (default: batch_*.txt)')
    
    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate subdomain format')
    validate_parser.add_argument('input_file', help='File to validate')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        if args.command == 'split':
            success = split_subdomains(
                args.input_file, 
                args.output_dir, 
                args.batch_size, 
                args.max_batches
            )
        elif args.command == 'merge':
            success = merge_batches(args.batch_dir, args.output_file, args.pattern)
        elif args.command == 'validate':
            success = validate_subdomains(args.input_file)
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n⚠️  Operation cancelled by user")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
