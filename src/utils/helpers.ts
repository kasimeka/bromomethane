export function stripMarkdown(text: string): string {
	if (!text) return ""; // Handle null or undefined input

	return (
		text
			// --- Add HTML tag removal FIRST ---
			.replace(/<[^>]*>/g, "") // Remove HTML tags like <h1>, <i>, etc.

			// --- Existing replacements ---
			.replace(/#{1,6}\s/g, "") // Remove headers (#)
			.replace(/[*_]{1,3}(.*?)[*_]{1,3}/g, "$1") // Remove bold/italic (*_)
			.replace(/\[([^\]]+)\]\([^\)]+\)/g, "$1") // Remove links ([text](url))
			.replace(/!\[([^\]]+)\]\([^\)]+\)/g, "$1") // Remove images (![alt](url))
			.replace(/^\s*>\s/gm, "") // Remove blockquotes (>)
			.replace(/```[\s\S]*?```/g, "") // Remove code blocks (```)
			.replace(/`([^`]+)`/g, "$1") // Remove inline code (`)
			.replace(/^\s*[-*_]{3,}\s*$/gm, "") // Remove horizontal rules (--- *** ___)
			.replace(/^[\s*-]+(.*)/gm, "$1") // Remove list markers (might be too aggressive sometimes)

			// --- Cleanup ---
			.replace(/\n\s*\n/g, "\n") // Consolidate multiple newlines
			.replace(/\s+/g, ' ')      // Replace consecutive whitespace (including newlines from tag removal) with a single space
			.trim()
	);
}

export function truncateText(text: string, maxLength: number = 65): string {
	if (!text) return ""; // Handle null or undefined input
	if (text.length <= maxLength) return text;
	return text.slice(0, maxLength).trim() + "...";
}
